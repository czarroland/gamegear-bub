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
    'sms-raster-224.sms':'MasterSystem',
    'sms-raster-240.sms':'MasterSystem',
}

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--tag',required=True)
    parser.add_argument('--source-commit',required=True)
    parser.add_argument('--bitstream',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not args.tag.startswith('v') or not args.tag.endswith('-alpha.4'):
        raise SystemExit('This SMS NTSC preview recipe is for the immutable alpha.4 tag')
    if len(args.source_commit)!=40 or any(c not in '0123456789abcdef' for c in args.source_commit):
        raise SystemExit('Pass the exact 40-character public source commit SHA')
    output=args.output.resolve()
    if output.exists():
        raise SystemExit(f'Refusing to overwrite release directory: {output}')
    stage=output/'stage'
    output.mkdir(parents=True)
    subprocess.run([sys.executable,str(ROOT/'scripts/package_core.py'),
        '--bitstream',str(args.bitstream.resolve()),'--output',str(stage),
        '--source-commit',args.source_commit],check=True)
    for filename,system in DIAGNOSTICS.items():
        source=ROOT/'diagnostics'/filename
        if len(source.read_bytes())!=32768 and filename!='gamegear-diagnostic.gg':
            raise SystemExit(f'Unexpected diagnostic length: {filename}')
        target=stage/'roms'/system/filename
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,target)
    for filename in ('LICENSE-GPL-V3','NOTICE.md'):
        shutil.copyfile(ROOT/filename,stage/filename)
    install=f'''Sega 8-bit GG + SMS NTSC preview for Gamebub rev4 ({args.tag})
================================================================

Source commit: {args.source_commit}
Bitstream SHA-256: {sha256(args.bitstream)}

Extract this ZIP at the root of the BUB SD card. It adds cores/Sega8bit.Dev
and original, redistributable test ROMs under roms/GameGear and
roms/MasterSystem. Keep the existing GameGear.Scale23 package for rollback.
The same core entry accepts .gg and .sms files. GG defaults to sharp 3x;
SMS defaults to sharp 2x. SMS 3x is a zoom with vertical cropping and an
additional eight-source-column crop on each side of 720-pixel HDMI output.

The existing v1.1-beta custom core-loading firmware can use consistent
TMR SEGA headers or a forced System setting. Automatic extension hints need
the optional companion firmware patch and are not required for the included
diagnostics. Boot one of those headered diagnostics first to reach the menu
before selecting a forced System for a headerless title. No firmware image
is bundled or installed by this package.

This is an SMS NTSC test checkpoint. PAL timing, FM synthesis, save states,
complete mapper/EEPROM coverage and long hardware soaks are not verified.
Back up saves. The firmware derives .sav from the ROM basename, so GG and
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
    name=f'Sega8bit-Gamebub-{args.tag}-rev4.zip'
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
        'bitstream_sha256':sha256(args.bitstream),'asset':name,
        'asset_sha256':sha256(archive),'files':len(files)+1}
    (output/'RELEASE_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':
    main()
