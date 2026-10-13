#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package an existing Xilinx bitstream and the beta firmware's descriptors."""
import argparse,json,shutil,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--bitstream',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--core-id',help='Package under a separate core ID for hardware trials')
    parser.add_argument('--core-name',help='Display name for a separate hardware trial')
    args=parser.parse_args()
    bitstream=args.bitstream.read_bytes()
    if not bitstream.startswith(b'\x00\x09\x0f\xf0\x0f\xf0\x0f\xf0\x0f\xf0\x00\x00\x01a'):
        raise SystemExit('Expected a raw Xilinx .bit with its header; do not supply .rbf, .bin, or .bit.hs.')
    metadata=json.loads((ROOT/'metadata/core.json').read_text())
    if args.core_id:
        metadata['metadata']['id']=args.core_id
    if args.core_name:
        metadata['metadata']['name']=args.core_name
    folder=args.output/'cores'/metadata['metadata']['id']
    folder.mkdir(parents=True,exist_ok=False)
    (folder/'core.json').write_text(json.dumps(metadata,indent=2)+'\n')
    for name in ['files.json','settings.json']:
        shutil.copyfile(ROOT/'metadata'/name,folder/name)
    filename=metadata['bitstreams'][0]['filename']
    (folder/filename).write_bytes(bitstream)
    (folder/'build-info.json').write_text(json.dumps({'bytes':len(bitstream),
        'crc32':f'{zlib.crc32(bitstream):08x}','source_bitstream':args.bitstream.name},indent=2)+'\n')
    print(folder.resolve())
if __name__=='__main__':main()
