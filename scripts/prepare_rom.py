#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Write a headerless GG copy; never change the supplied ROM."""
import argparse,json,zlib
from pathlib import Path
def header_positions(data):
    return [p for p in [0x1ff0,0x3ff0,0x7ff0] if data[p:p+8]==b'TMR SEGA']
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('source',type=Path);parser.add_argument('output',type=Path)
    args=parser.parse_args()
    if args.source.resolve()==args.output.resolve(): raise SystemExit('Choose a separate output filename.')
    data=args.source.read_bytes(); stripped=0
    if len(data)%16384==512 and not header_positions(data) and header_positions(data[512:]):
        data=data[512:];stripped=512
    if not 32768<=len(data)<=4194304: raise SystemExit('This checkpoint accepts 32 KiB to 4 MiB GG ROMs.')
    padding=(-len(data))%4
    if len(data)+padding>4194304:raise SystemExit('Padded ROM exceeds 4 MiB.')
    data+=b'\xff'*padding
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.open('xb') as out:out.write(data)
    print(json.dumps({'output':str(args.output),'bytes':len(data),'stripped_copier_bytes':stripped,
        'alignment_padding':padding,'sega_header_positions':header_positions(data),
        'crc32':f'{zlib.crc32(data):08x}'},indent=2))
if __name__=='__main__':main()
