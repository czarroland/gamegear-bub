#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage the pinned Sega engine without changing the Gamebub framework."""
import argparse, difflib, hashlib, json, re, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REV = 'f875eb70ccd9023802ee41bb28686d11d65ee717'
VHDL = [
    'jt89/jt89.vhd', 'T80/T80_Reg.vhd', 'T80/T80_MCode.vhd',
    'T80/T80_ALU.vhd', 'T80/T80.vhd', 'T80/T80s.vhd',
    'vdp_sprite_shifter.vhd', 'vdp_background.vhd', 'vdp_sprites.vhd',
    'vdp_main.vhd', 'vdp_cram.vhd', 'vdp.vhd', 'io.vhd',
    'mapper_detect.vhd', 'mapper_ctrl.vhd', 'memory_decode.vhd',
    'memory_bus.vhd', 'evolution_mapper.vhd', 'evolution_rom_address.vhd',
    'eeprom_93c46.vhd', 'cart_eeprom.vhd', 'AudioMix.vhd',
    'video.vhd', 'system.vhd',
]
VERILOG = [f'jt89/{n}.v' for n in ['jt89', 'jt89_noise', 'jt89_mixer', 'jt89_tone', 'jt89_vol']]

def patch_system(s):
    def cut(start, end, replacement):
        nonlocal s
        a = s.index(start); b = s.index(end, a)
        s = s[:a] + replacement + s[b:]
    # This staged variant is GG-only: unavailable peripherals are excluded
    # explicitly rather than leaving unresolved mixed-language instances.
    cut('\tGAMEGENIE : component CODES', '\tz80_inst:',
        "\tGG_AVAIL <= '0';\n\tGENIE_DI <= D_out;\n\n")
    cut('\tfm: work.opll', '\tprocess (clk_sys)',
        "\tFM_out <= (others => '0');\n\n")
    cut('\tboot_rom_inst : entity work.sprom', '\tevolution_menu_mode',
        "\tboot_rom_D_out <= (others => '1');\n\n")
    cut('\text_bios_inst : entity work.spram', '\tmc8123_inst',
        "\text_bios_D_out <= (others => '1');\n\text_gg_bios_D_out <= (others => '1');\n\n")
    cut('\tmc8123_inst', '\t-- -----------------------------------------------------------------------',
        "\tmc8123_D_out <= rom_do;\n\tsegadect2_D_out <= rom_do;\n\tkey_a <= (others => '0');\n\n")
    s = s.replace('\t\tRESET_n:', "\t\trom_wait_n : in std_logic := '1';\n\t\tRESET_n:", 1)
    s = s.replace('\t\tCEN\t\t=> ce_z80,', '\t\tCEN\t\t=> ce_z80,\n\t\tWAIT_n => rom_wait_n,', 1)
    return s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--upstream', type=Path)
    args = ap.parse_args()
    vendor = ROOT/'vendor/sms_mister'
    if args.upstream:
        rev = subprocess.check_output(['git', '-C', str(args.upstream), 'rev-parse', 'HEAD'], text=True).strip()
        if rev != REV: raise SystemExit(f'Expected {REV}, found {rev}')
        for rel in VHDL + VERILOG:
            p = vendor/'rtl'/rel; p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(args.upstream/'rtl'/rel, p)
        (vendor/'UPSTREAM.json').write_text(json.dumps({'repository':'https://github.com/MiSTer-devel/SMS_MiSTer','revision':REV},indent=2)+'\n')
    stage = ROOT/'rtl/generated'
    if stage.exists(): shutil.rmtree(stage)
    entries = []
    for rel in VHDL + VERILOG:
        original = vendor/'rtl'/rel
        raw = original.read_bytes()
        text = raw.decode().replace('\r\n','\n')
        patched = patch_system(text) if rel == 'system.vhd' else text
        # Vivado unifies VHDL and Verilog library names. The upstream package
        # named jt89 shadows the Verilog jt89 module, leaving its component a
        # black box. Keep the component name and rename only the package.
        if rel == 'jt89/jt89.vhd':
            patched = patched.replace('package jt89 is', 'package jt89_pkg is', 1)
        elif rel == 'system.vhd':
            patched = patched.replace('use work.jt89.all;', 'use work.jt89_pkg.all;', 1)
        if rel.endswith('.vhd'):
            # Keep VHDL names legal in the GHDL-generated Verilog simulator.
            for name,replacement in [('DO','z80_dout'),('Reg','z80_registers'),('priority','bg_priority')]:
                patched=re.sub(r'\b'+name+r'\b',replacement,patched,flags=re.I)
            patched = re.sub(r'(?m)^(\s*\w+\s*:\s*)work\.(\w+)', r'\1entity work.\2', patched)
            constants=dict(re.findall(r'constant\s+(\w+)\s*:[^;]*?:=\s*"([01]+)"',patched,re.I))
            patched=re.sub(r"(when\s+)'([01])'\s*&\s*(\w+)",
                lambda m:m[1]+'"'+m[2]+constants[m[3]]+'"' if m[3] in constants else m[0],patched,flags=re.I)
            if rel=='mapper_ctrl.vhd':
                patched=re.sub(r'(case A\(1 downto 0\) is.*?)(end case;)',
                    lambda m:m[1]+"when others => null;\n"+m[2],patched,flags=re.S)
            if rel=='T80/T80.vhd':
                patched=patched.replace('ioq and x"7"','ioq and "000000111"')
                patched=re.sub(r'(?mi)^(\s*)ALU\s*:',r'\1alu_inst:',patched)
        dest = stage/Path(rel).with_suffix('.vhdl' if rel.endswith('.vhd') else '.v')
        dest.parent.mkdir(parents=True, exist_ok=True); dest.write_text(patched)
        entries.append({'upstream':f'rtl/{rel}', 'sha256':hashlib.sha256(raw).hexdigest(),
                        'staged':str(dest.relative_to(ROOT)), 'staged_sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
        if patched != text:
            patch = ''.join(difflib.unified_diff(text.splitlines(True),patched.splitlines(True),fromfile=f'a/rtl/{rel}',tofile=f'b/rtl/{rel}'))
            pp=ROOT/'patches'/Path(rel.replace('/','__')).with_suffix('.patch'); pp.parent.mkdir(parents=True,exist_ok=True); pp.write_text(patch)
    manifest=ROOT/'manifests/sources.json'; manifest.parent.mkdir(parents=True,exist_ok=True)
    manifest.write_text(json.dumps({'revision':REV,'files':entries},indent=2)+'\n')
    print(f'Staged {len(entries)} Sega sources from {REV[:12]}')

if __name__ == '__main__': main()
