#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Use the untouched Gamebub builder with an external VHDL-2008 file setting."""
import argparse, importlib.util, shutil, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--target',default='gamebub_rev4',choices=['gamebub_rev4'])
    args=parser.parse_args()
    if not shutil.which('vivado'):
        raise SystemExit('Vivado is required for a bitstream; source the Vivado settings64.sh first.')
    for script in ['prepare_sources.py','generate_machine.py']:
        subprocess.run([sys.executable,str(ROOT/'scripts'/script)],check=True,cwd=ROOT)
    spec=importlib.util.spec_from_file_location('gamebub_build',ROOT/'framework/scripts/build_core.py')
    builder=importlib.util.module_from_spec(spec)
    sys.modules[spec.name]=builder
    spec.loader.exec_module(builder)
    original_tool_lookup=builder.get_edatool
    def configured_tool_lookup(name):
        tool=original_tool_lookup(name)
        def factory(*tool_args,**kwargs):
            for source in kwargs['edam']['files']:
                if source['file_type']=='vhdlSource': source['file_type']='vhdlSource-2008'
            return tool(*tool_args,**kwargs)
        return factory
    builder.get_edatool=configured_tool_lookup
    name=f'GameGearCore-{args.target}'
    builder.main(['--name',name,'--target',args.target,'--core-class','GameGearCore',
        '--build-root',str(ROOT/'build'/name),'--additional-file-dirs',str(ROOT/'rtl'),
        '--project-root',str(ROOT)])
if __name__=='__main__':main()
