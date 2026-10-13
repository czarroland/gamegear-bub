#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import argparse,json,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--synthesize',action='store_true');args=ap.parse_args()
    ghdl=os.environ.get('GHDL') or shutil.which('ghdl')
    if not ghdl:raise SystemExit('GHDL missing; set GHDL to the executable or install GHDL')
    output=ROOT/'build/ghdl';output.mkdir(parents=True,exist_ok=True)
    for p in output.glob('work-obj*.cf'):p.unlink()
    opts=['--std=08','-fsynopsys','-frelaxed-rules',f'--workdir={output}']
    files=[ROOT/'rtl/portable/dpram.vhdl',ROOT/'rtl/portable/spram.vhdl']
    manifest=json.loads((ROOT/'manifests/sources.json').read_text())
    files.extend(ROOT/f['staged'] for f in manifest['files'] if f['staged'].endswith('.vhdl'))
    files.append(ROOT/'rtl/platform/gamegear_machine.vhdl')
    subprocess.run([ghdl,'-a',*opts,*map(str,files)],check=True,cwd=ROOT)
    print('PASS: real VHDL engine analyzed')
    if args.synthesize:
      dest=ROOT/'build/gamegear_machine.v';
      with dest.open('w') as f:
        subprocess.run([ghdl,'--synth',*opts,'--out=verilog','--latches','gamegear_machine'],stdout=f,check=True,cwd=ROOT)
      print(f'Generated real engine Verilog for mixed-language simulation: {dest}')
if __name__=='__main__':main()
