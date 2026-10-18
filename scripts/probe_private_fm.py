#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Synthesize a local-only MiSTer VM2413 integration without vendoring it.

This probe writes exclusively under ignored build/. Its output is not a
redistribution clearance or a release artifact.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

from run_fm_oracle import prepare

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream', type=Path, default=ROOT / 'build/upstream-sms')
    parser.add_argument('--simulate-tone', action='store_true',
                        help='Also run the original SMS ROM through the private OPLL netlist')
    args = parser.parse_args()
    source_dir = args.upstream.resolve() / 'rtl/VM2413'
    manifest = json.loads((ROOT / 'manifests/fm_oracle_sources.json').read_text())
    expected = {'OPLL.qip': manifest['qip_sha256'], **manifest['files']}
    for name, digest in expected.items():
        path = source_dir / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit(f'Pinned local VM2413 source missing or changed: {path}')
    ghdl = shutil.which('ghdl')
    if not ghdl:
        raise SystemExit('GHDL is required; run inside the local test container')
    work = ROOT / 'build/private-fm-probe'
    source_stage = work / 'vm2413'
    ghdl_work = work / 'ghdl'
    work.mkdir(parents=True, exist_ok=True)
    if source_stage.exists(): shutil.rmtree(source_stage)
    if ghdl_work.exists(): shutil.rmtree(ghdl_work)
    ghdl_work.mkdir()
    order = prepare(source_dir, source_stage)
    system = (ROOT / 'rtl/generated/system.vhdl').read_text()
    original = (ROOT / 'vendor/sms_mister/rtl/system.vhd').read_text()
    fm = re.search(r'\tfm: work\.opll\b.*?(?=\tprocess \(clk_sys\))', original, re.S)
    if fm is None or system.count("\tFM_out <= (others => '0');") != 1:
        raise SystemExit('Staged system FM replacement anchor changed')
    fm_instance = fm.group().replace('fm: work.opll', 'fm: entity work.opll', 1)
    private_system = work / 'system.vhdl'
    private_system.write_text(system.replace("\tFM_out <= (others => '0');", fm_instance, 1))
    stage_manifest = json.loads((ROOT / 'manifests/sources.json').read_text())
    engine = [ROOT / entry['staged'] for entry in stage_manifest['files']
              if entry['staged'].endswith('.vhdl') and not entry['staged'].endswith('/system.vhdl')]
    sources = ([ROOT / 'rtl/portable/dpram.vhdl', ROOT / 'rtl/portable/spram.vhdl'] +
               engine + [source_stage / name for name in order] +
               [private_system, ROOT / 'rtl/platform/gamegear_machine.vhdl'])
    flags = ['--std=08', '-fsynopsys', '-frelaxed-rules', '-fexplicit', '-C',
             f'--workdir={ghdl_work}']
    log = work / 'ghdl.log'
    with log.open('w') as output:
        for source in sources:
            subprocess.run([ghdl, '-a', *flags, str(source)], cwd=ROOT,
                           stdout=output, stderr=subprocess.STDOUT, check=True)
        with (work / 'gamegear_machine.v').open('w') as verilog:
            subprocess.run([ghdl, '--synth', *flags, '--out=verilog', '--latches',
                            'gamegear_machine'], cwd=ROOT, stdout=verilog,
                           stderr=output, check=True)
    print(f'PASS private VM2413 integration synthesis: {work / "gamegear_machine.v"}')
    if args.simulate_tone:
        verilator = shutil.which('verilator')
        if not verilator:
            raise SystemExit('Verilator is required for --simulate-tone')
        directory = work / 'verilator_tone'
        jt89 = sorted((ROOT / 'rtl/generated/jt89').glob('*.v'))
        if not jt89:
            raise SystemExit('Generated JT89 sources are missing')
        command = [verilator, '--binary', '--timing', '-Wno-fatal',
                   '-GEXPECT_FM_SOUND=1', '--top-module', 'tb_sms_fm_control',
                   '--Mdir', str(directory), '-j', '2',
                   str(work / 'gamegear_machine.v'),
                   *map(str, jt89), str(ROOT / 'rtl/platform/gg_enables.sv'),
                   str(ROOT / 'tests/tb_sms_fm_control.sv')]
        with (work / 'verilator_tone.log').open('w') as output:
            subprocess.run(command, cwd=ROOT, stdout=output,
                           stderr=subprocess.STDOUT, check=True)
        result = subprocess.run([directory / 'Vtb_sms_fm_control'], cwd=ROOT,
                                text=True, capture_output=True, check=True)
        if 'PASS private SMS FM tone reaches mixed audio' not in result.stdout:
            raise SystemExit(f'Private tone test did not report audio pass:\n{result.stdout}')
        print(result.stdout.splitlines()[0])
    print('Local experiment only; do not publish the generated source or bitstream.')


if __name__ == '__main__': main()
