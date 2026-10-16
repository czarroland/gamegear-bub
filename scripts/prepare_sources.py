#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage the pinned Sega engine without changing the Gamebub framework."""
import argparse, difflib, hashlib, json, re, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REV = '8443a0d19a88aff7a5900011bccf386daf146945'
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

def rename_vhdl_identifiers(source):
    """Rename simulator-hostile identifiers in VHDL code, never in prose or literals."""
    names = {'do': 'z80_dout', 'reg': 'z80_registers', 'priority': 'bg_priority'}
    identifier = re.compile(r'\b(?:do|reg|priority)\b', re.I)
    result = []
    index = 0
    while index < len(source):
        if source.startswith('--', index):
            end = source.find('\n', index)
            if end < 0:
                result.append(source[index:])
                break
            result.append(source[index:end + 1])
            index = end + 1
        elif source[index] == '"':
            end = index + 1
            while end < len(source):
                if source[end] == '"':
                    end += 1
                    if end < len(source) and source[end] == '"':
                        end += 1
                        continue
                    break
                end += 1
            result.append(source[index:end])
            index = end
        else:
            end = index
            while end < len(source) and source[end] != '"' and not source.startswith('--', end):
                end += 1
            result.append(identifier.sub(lambda match: names[match.group().lower()], source[index:end]))
            index = end
    return ''.join(result)

def patch_system(s):
    def cut(start, end, replacement):
        nonlocal s
        if s.count(start) != 1:
            raise ValueError(f'Expected one system cut start: {start!r}')
        a = s.index(start)
        b = s.find(end, a + len(start))
        if b < 0:
            raise ValueError(f'Missing system cut end after {start!r}: {end!r}')
        s = s[:a] + replacement + s[b:]
    def replace_once(old, new):
        nonlocal s
        if s.count(old) != 1:
            raise ValueError(f'Expected one system replacement anchor: {old!r}')
        s = s.replace(old, new, 1)
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
    replace_once('\t\tRESET_n:', "\t\trom_wait_n : in std_logic := '1';\n\t\tRESET_n:")
    replace_once('\t\tCEN\t\t=> ce_z80,', '\t\tCEN\t\t=> ce_z80,\n\t\tWAIT_n => rom_wait_n,')
    return s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--upstream', type=Path)
    args = ap.parse_args()
    vendor = ROOT/'vendor/sms_mister'
    if args.upstream:
        rev = subprocess.check_output(['git', '-C', str(args.upstream), 'rev-parse', 'HEAD'], text=True).strip()
        if rev != REV: raise SystemExit(f'Expected {REV}, found {rev}')
        missing = [rel for rel in VHDL + VERILOG if not (args.upstream/'rtl'/rel).is_file()]
        if missing: raise SystemExit(f'Missing upstream sources: {missing}')
        # Check the whole selected snapshot before replacing any vendored file.
        for rel in VHDL + VERILOG:
            raw = (args.upstream/'rtl'/rel).read_bytes()
            try:
                source = raw.decode('utf-8').replace('\r\n', '\n')
            except UnicodeDecodeError as error:
                raise ValueError(f'Unsupported source encoding: rtl/{rel}') from error
            if rel == 'system.vhd':
                patch_system(source)
        for rel in VHDL + VERILOG:
            p = vendor/'rtl'/rel; p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(args.upstream/'rtl'/rel, p)
        (vendor/'UPSTREAM.json').write_text(json.dumps({'repository':'https://github.com/MiSTer-devel/SMS_MiSTer','revision':REV},indent=2)+'\n')
    else:
        metadata = json.loads((vendor/'UPSTREAM.json').read_text())
        manifest = json.loads((ROOT/'manifests/sources.json').read_text())
        if metadata.get('revision') != REV or manifest.get('revision') != REV:
            raise SystemExit('Sega source revision differs from the pinned staging revision')
        expected = {entry['upstream']: entry['sha256'] for entry in manifest['files']}
        names = {f'rtl/{rel}' for rel in VHDL + VERILOG}
        if set(expected) != names:
            raise SystemExit('Sega source manifest does not match the selected source set')
        for rel in VHDL + VERILOG:
            raw = (vendor/'rtl'/rel).read_bytes()
            if hashlib.sha256(raw).hexdigest() != expected[f'rtl/{rel}']:
                raise SystemExit(f'Sega source hash mismatch: rtl/{rel}')
    stage = ROOT/'rtl/generated'
    if stage.exists(): shutil.rmtree(stage)
    entries = []
    for rel in VHDL + VERILOG:
        original = vendor/'rtl'/rel
        raw = original.read_bytes()
        try:
            text = raw.decode('utf-8').replace('\r\n','\n')
        except UnicodeDecodeError as error:
            raise ValueError(f'Unsupported source encoding: rtl/{rel}') from error
        patched = patch_system(text) if rel == 'system.vhd' else text
        # Vivado unifies VHDL and Verilog library names. The upstream package
        # named jt89 shadows the Verilog jt89 module, leaving its component a
        # black box. Keep the component name and rename only the package.
        if rel == 'jt89/jt89.vhd':
            if patched.count('package jt89 is') != 1:
                raise ValueError('Expected one JT89 package declaration')
            patched = patched.replace('package jt89 is', 'package jt89_pkg is', 1)
        elif rel == 'system.vhd':
            if patched.count('use work.jt89.all;') != 1:
                raise ValueError('Expected one JT89 package import')
            patched = patched.replace('use work.jt89.all;', 'use work.jt89_pkg.all;', 1)
        if rel.endswith('.vhd'):
            # Keep VHDL names legal in the GHDL-generated Verilog simulator.
            patched = rename_vhdl_identifiers(patched)
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
                        'newline_normalization': 'CRLF to LF' if b'\r\n' in raw else 'none',
                        'staged':str(dest.relative_to(ROOT)), 'staged_sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
        pp=ROOT/'patches'/Path(rel.replace('/','__')).with_suffix('.patch')
        if patched != text:
            patch = ''.join(difflib.unified_diff(text.splitlines(True),patched.splitlines(True),fromfile=f'a/rtl/{rel}',tofile=f'b/rtl/{rel}'))
            pp.parent.mkdir(parents=True,exist_ok=True); pp.write_text(patch)
        else:
            pp.unlink(missing_ok=True)
    manifest=ROOT/'manifests/sources.json'; manifest.parent.mkdir(parents=True,exist_ok=True)
    manifest.write_text(json.dumps({'revision':REV,'files':entries},indent=2)+'\n')
    print(f'Staged {len(entries)} Sega sources from {REV[:12]}')

if __name__ == '__main__': main()
