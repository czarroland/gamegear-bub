#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Package an existing Xilinx bitstream and the beta firmware's descriptors."""
import argparse,hashlib,json,shutil,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def validate_metadata(core,files,settings):
    identity=core['metadata']
    for key in ('id','name','author'):
        if not identity[key] or len(identity[key].encode())>32:
            raise ValueError(f'core {key} exceeds the firmware 32-byte limit')
    bitstreams=core['bitstreams']
    if len(bitstreams)!=1 or bitstreams[0]['target']!='gamebub_rev4':
        raise ValueError('expected exactly one rev4 bitstream')
    filename=bitstreams[0]['filename']
    if Path(filename).name!=filename or not filename.endswith('.bit'):
        raise ValueError('invalid bitstream filename')
    ids=set()
    for entry in files['files']:
        if entry['id'] in ids or len(entry['label'].encode())>16:
            raise ValueError('duplicate file ID or label exceeds firmware limit')
        ids.add(entry['id'])
        extensions=entry['extensions']
        if len(extensions)>4 or any(len(ext.encode())>8 for ext in extensions):
            raise ValueError('file extensions exceed firmware limits')
        if entry.get('max_transfer_speed')!=5000:
            raise ValueError('ROM/save SPI speed must use the proven 5000 KB/s setting')
        hint=entry.get('load_type_hint')
        if hint:
            if (int(hint['guard_address'],0)!=0 or
                int(hint['guard_value'],0)!=0x53454732 or
                int(hint['address'],0)!=0x30 or
                hint['extensions']!={'gg':1,'sms':2} or
                set(extensions)!={'gg','sms'}):
                raise ValueError('load hint does not match SEG2 ROM picker')
    if ids!={0,1} or files['files'][1].get('dependent_on_0') is not True:
        raise ValueError('expected one ROM picker and its dependent save slot')
    setting_ids=set()
    for entry in settings['settings']:
        if entry['id'] in setting_ids:
            raise ValueError('duplicate setting ID')
        setting_ids.add(entry['id'])
        if entry['type']=='list':
            items=entry['items']
            if not items or len(items)>8 or items[0]['value']!=entry['default']:
                raise ValueError('list default must be the first firmware fallback item')
            if len({item['value'] for item in items})!=len(items):
                raise ValueError('duplicate setting values')
    if setting_ids!={1,2,3,4,6,8,9,10,11,12,13}:
        raise ValueError('unexpected SEG2 setting IDs')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--bitstream',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--core-id',help='Package under a separate core ID for hardware trials')
    parser.add_argument('--core-name',help='Display name for a separate hardware trial')
    parser.add_argument('--source-commit',help='Public source commit for this exact bitstream build')
    parser.add_argument('--package-source-commit',help='Public source commit for package metadata when repackaging an existing bitstream')
    args=parser.parse_args()
    bitstream=args.bitstream.read_bytes()
    if not bitstream.startswith(b'\x00\x09\x0f\xf0\x0f\xf0\x0f\xf0\x0f\xf0\x00\x00\x01a'):
        raise SystemExit('Expected a raw Xilinx .bit with its header; do not supply .rbf, .bin, or .bit.hs.')
    metadata=json.loads((ROOT/'metadata/core.json').read_text())
    if args.core_id:
        metadata['metadata']['id']=args.core_id
    if args.core_name:
        metadata['metadata']['name']=args.core_name
    files=json.loads((ROOT/'metadata/files.json').read_text())
    settings=json.loads((ROOT/'metadata/settings.json').read_text())
    validate_metadata(metadata,files,settings)
    folder=args.output/'cores'/metadata['metadata']['id']
    folder.mkdir(parents=True,exist_ok=False)
    (folder/'core.json').write_text(json.dumps(metadata,indent=2)+'\n')
    for name in ['files.json','settings.json']:
        shutil.copyfile(ROOT/'metadata'/name,folder/name)
    filename=metadata['bitstreams'][0]['filename']
    (folder/filename).write_bytes(bitstream)
    (folder/'build-info.json').write_text(json.dumps({'bytes':len(bitstream),
        'crc32':f'{zlib.crc32(bitstream):08x}',
        'sha256':hashlib.sha256(bitstream).hexdigest(),
        'source_bitstream':args.bitstream.name,
        'source_commit':args.source_commit,
        'package_source_commit':args.package_source_commit or args.source_commit},indent=2)+'\n')
    print(folder.resolve())
if __name__=='__main__':main()
