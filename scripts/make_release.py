#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build one deterministic rev4 community-test ZIP from a routed bitstream."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DIAGNOSTICS={
    'gamegear-diagnostic.gg':'GameGear',
    'sms-pause-diagnostic.sms':'MasterSystem',
    'sms-raster-192.sms':'MasterSystem',
    'sms-raster-224.sms':'MasterSystem',
    'sms-raster-240.sms':'MasterSystem',
    'sms-top-row-diagnostic.sms':'MasterSystem',
}
TEST_LOGS=('engine.log','engine-four-state.log','sms_engine.log',
           'sms_top_row.log','sms_fm_control.log','soc.log','sms-pause.log',
           'input-mapper.log','video-viewport.log') + tuple(
               f'sms-raster-{height}{suffix}.log'
               for suffix in ('','-pal') for height in (192,224,240))

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--tag',required=True)
    parser.add_argument('--source-commit',required=True)
    parser.add_argument('--package-source-commit',help='Metadata commit when reusing an earlier bitstream')
    parser.add_argument('--bitstream',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--test-log-dir',type=Path,
                        help='Directory containing passing diagnostic ROM simulation logs')
    args=parser.parse_args()
    suffix=args.tag.removeprefix('v0.1.0-alpha.')
    if (not args.tag.startswith('v0.1.0-alpha.') or not suffix.isdecimal() or
        int(suffix)<4 or str(int(suffix))!=suffix):
        raise SystemExit('Expected a v0.1.0-alpha.N tag with N >= 4')
    if len(args.source_commit)!=40 or any(c not in '0123456789abcdef' for c in args.source_commit):
        raise SystemExit('Pass the exact 40-character public source commit SHA')
    if int(suffix)>=7 and not args.test_log_dir:
        raise SystemExit('Alpha.7 and later require --test-log-dir')
    package_commit=args.package_source_commit or args.source_commit
    if len(package_commit)!=40 or any(c not in '0123456789abcdef' for c in package_commit):
        raise SystemExit('Pass the exact 40-character package source commit SHA')
    output=args.output.resolve()
    if output.exists():
        raise SystemExit(f'Refusing to overwrite release directory: {output}')
    stage=output/'stage'
    output.mkdir(parents=True)
    subprocess.run([sys.executable,str(ROOT/'scripts/package_core.py'),
        '--bitstream',str(args.bitstream.resolve()),'--output',str(stage),
        '--source-commit',args.source_commit,
        '--package-source-commit',package_commit],check=True)
    for filename,system in DIAGNOSTICS.items():
        source=ROOT/'diagnostics'/filename
        if len(source.read_bytes())!=32768 and filename!='gamegear-diagnostic.gg':
            raise SystemExit(f'Unexpected diagnostic length: {filename}')
        target=stage/'roms'/system/filename
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    for filename in ('LICENSE-GPL-V3','NOTICE.md'):
        shutil.copyfile(ROOT/filename,stage/filename)
    if args.test_log_dir:
        log_dir=args.test_log_dir.resolve()
        summary=json.loads((log_dir/'test-results.json').read_text())
        checks={entry['check']:entry['result'] for entry in summary['checks']}
        for label in (name.removesuffix('.log') for name in TEST_LOGS):
            if checks.get(label)!='pass':
                raise SystemExit(f'Missing passing check in test-results.json: {label}')
        destination=stage/'test-logs'
        destination.mkdir()
        shutil.copyfile(log_dir/'test-results.json',destination/'test-results.json')
        for filename in TEST_LOGS:
            shutil.copyfile(log_dir/filename,destination/filename)
        (destination/'README.txt').write_text(
            'These logs are simulations of original, redistributable diagnostic ROMs\n'
            'and platform logic. They are not retail ROM test results or proof of\n'
            'operation on Gamebub hardware. The current release still needs a\n'
            'device play check. No commercial ROM bytes are included.\n\n'
            'The FM control diagnostic checks register writes/readback only.\n'
            'It does not test or enable audible FM synthesis.\n\n'
            'Separate PAL trial hardware feedback, 2026-10-17: several PAL\n'
            'ROMs played and the requested test ROMs ran. Filenames, hashes,\n'
            'firmware version, and per-game observations were not provided.\n')
    regression_note='''Alpha.4 showed commercial-game video failures on hardware. For this newer tag,
verify the diagnostic Start color change and the transition into gameplay in
both GG and SMS games before treating the build as playable. Alpha.3 remains
the known-good GG rollback.
''' if int(suffix)>4 else ''
    control_note='''This build maps ten commands: directions, A/B, Start/Pause,
3x crop up/down, and optional SMS Reset. Any D-pad, A/B/X/Y, L/R, Start, or
Select button can be assigned to each command. Open Map controls in Settings,
tap one button to bind each prompt, hold one button for a second to keep its
current binding, or hold Start+Select for a second to exit. The default crop
buttons are L/R. The on-screen bindings last until the core powers off;
Swap A/B remains a separate persistent menu setting. SMS Reset is disabled
by default and requires the Hold 1s Reset setting when enabled.

After selecting Map controls, manually exit the core settings menu to see
the mapping prompt. This is a known issue:
https://github.com/czarroland/gamegear-bub/issues/9
This ZIP does not contain or modify Gamebub firmware.
''' if int(suffix)>=9 else '''This build adds 3x crop with L/R one-pixel picture
movement, an on-screen six-command press-to-bind mapper, a persistent Swap A/B
menu choice, Start/Pause debounce, and a safe SMS Select default. Open Map
controls in Settings, then press one button for each prompt. Start exits;
Select keeps a binding. The on-screen bindings last until core power-off.
SMS Select defaults to no action; the optional Hold 1s Reset setting restores
a guarded reset shortcut.
'''
    install=f'''GG and SMS Bub for Gamebub rev4 ({args.tag})
================================================================

Bitstream source commit: {args.source_commit}
Package source commit: {package_commit}
Bitstream SHA-256: {sha256(args.bitstream)}

Original Game Gear support in the MiSTer Sega core was authored by GreyRogue:
https://github.com/MiSTer-devel/SMS_MiSTer/pull/8
This is an AI-developed Gamebub port of the MiSTer engine, with human
direction and hardware testing. See NOTICE.md for full upstream credits.

Extract this ZIP at the root of the BUB SD card. The menu entry is named
"GG and SMS Bub". Its existing internal core ID, cores/Sega8bit.Dev, stays
the same so firmware settings and saves continue to use their current paths.
It includes original, redistributable test ROMs under roms/GameGear and
roms/MasterSystem. Keep the existing GameGear.Scale23 package for rollback.
The same core entry accepts .gg and .sms files. GG defaults to sharp 3x;
SMS defaults to sharp 2x. SMS 3x is a zoom with vertical cropping and an
additional eight-source-column crop on each side of 720-pixel HDMI output.

The existing v1.1-beta custom core-loading firmware can use consistent
TMR SEGA headers or a forced System setting. It does not pass filename
extension hints to the core. Boot one of the headered diagnostics first to
reach the menu before selecting a forced System for a headerless title. No
firmware image is bundled or installed by this package.

SMS PAL is selectable under Master System TV. Auto TV recognizes the exact
Alien 3 (Europe, Brazil) image and uses NTSC for unknown images.
{control_note}

The included test-logs directory records simulations with original test ROMs.
This combined build needs its own device play check. On the alpha.9 Next
Trial, Alien 3 flashes white, then stays black with no sound. Auto TV is not
a verified boot fix; see https://github.com/czarroland/gamegear-bub/issues/10.
FM synthesis, save states,
complete mapper/EEPROM coverage and long hardware soaks are not verified.
{regression_note}Back up saves. The firmware derives .sav from the ROM basename, so GG and
SMS files with the same basename in one directory share a save path. Keep
those files in separate directories. To remove this trial, back up saves and
delete only cores/Sega8bit.Dev and settings/Sega8bit.Dev.json.

Report the tag, ROM hash, System and size settings, firmware version, steps,
expected/actual result and any audio or save issue at
https://github.com/czarroland/gamegear-bub/issues.
'''
    (stage/'INSTALL.txt').write_text(install)
    files=sorted(path for path in stage.rglob('*') if path.is_file())
    sums=''.join(f'{sha256(path)}  {path.relative_to(stage).as_posix()}\n' for path in files)
    (stage/'SHA256SUMS.txt').write_text(sums)
    name=f'GG-and-SMS-Bub-{args.tag}-rev4.zip'
    archive=output/name
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as zipped:
        for path in sorted(path for path in stage.rglob('*') if path.is_file()):
            entry=zipfile.ZipInfo(path.relative_to(stage).as_posix(),(2026,10,16,0,0,0))
            entry.compress_type=zipfile.ZIP_DEFLATED
            entry.external_attr=0o644<<16
            zipped.writestr(entry,path.read_bytes(),compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        for path in stage.rglob('*'):
            if path.is_file():
                assert zipped.read(path.relative_to(stage).as_posix())==path.read_bytes()
    (output/'SHA256SUMS.txt').write_text(f'{sha256(archive)}  {name}\n')
    manifest={'tag':args.tag,'source_commit':args.source_commit,
        'package_source_commit':package_commit,
        'bitstream_sha256':sha256(args.bitstream),'asset':name,
        'asset_sha256':sha256(archive),'files':len(files)+1}
    (output/'RELEASE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':
    main()
