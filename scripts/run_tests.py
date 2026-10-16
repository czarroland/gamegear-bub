#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run the actual CPU/VDP/JT89 engine; save complete tool logs and results."""
import argparse,json,os,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'
def executable(name):
    value=os.environ.get(name.upper()) or shutil.which(name)
    if not value:raise SystemExit(f'Missing tool: {name}')
    return value
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--four-state',action='store_true',help='Also run the full engine in Icarus (slower).')
    args=parser.parse_args()
    BUILD.mkdir(exist_ok=True)
    results=[]
    def run(label,command):
        print(f'Running {label}',flush=True)
        start=time.monotonic()
        log=BUILD/(label+'.log')
        with log.open('w') as output:
            result=subprocess.run([str(a) for a in command],cwd=ROOT,stdout=output,stderr=subprocess.STDOUT)
        if result.returncode:
            print(log.read_text()[-5000:]);raise SystemExit(f'FAILED {label}; see {log}')
        results.append({'check':label,'result':'pass','seconds':round(time.monotonic()-start,2)})
        for line in log.read_text().splitlines():
            if 'PASS' in line:print(line)
    for script in ['prepare_sources.py','generate_machine.py','make_diagnostic.py',
                   'make_sms_pause_diagnostic.py']:
        run(script.removesuffix('.py'),[sys.executable,ROOT/'scripts'/script])
    run('staging-tests',[sys.executable,ROOT/'tests/test_prepare_sources.py'])
    run('engine-analysis',[sys.executable,ROOT/'scripts/analyze_engine.py','--synthesize'])
    run('memory-decode-oracle',[sys.executable,ROOT/'scripts/run_memory_decode_oracle.py'])
    ghdl=executable('ghdl');ivl=executable('iverilog');vvp=executable('vvp');verilator=executable('verilator')
    ivl_args=[ivl]
    if os.environ.get('IVL_BASE'):ivl_args+=['-B',os.environ['IVL_BASE']]
    run('rom-type-compile',ivl_args+['-g2012','-s','tb_rom_type','-o',BUILD/'tb_rom_type',
                                   'rtl/platform/sega_rom_type.sv','tests/tb_rom_type.sv'])
    run('rom-type',[vvp,BUILD/'tb_rom_type'])
    run('sms-pause-compile',ivl_args+['-g2012','-s','tb_sms_pause_guard','-o',BUILD/'tb_sms_pause_guard',
                                     'rtl/platform/sms_pause_guard.sv','tests/tb_sms_pause_guard.sv'])
    run('sms-pause',[vvp,BUILD/'tb_sms_pause_guard'])
    run('video-viewport-compile',ivl_args+['-g2012','-s','tb_video_viewport','-o',BUILD/'tb_video_viewport',
                                         'rtl/platform/gg_video.sv','tests/tb_video_viewport.sv'])
    run('video-viewport',[vvp,BUILD/'tb_video_viewport'])
    run('memory-compile',[ghdl,'-a','--std=08','--workdir='+str(BUILD/'ghdl'),ROOT/'tests/tb_memory.vhdl'])
    run('memory',[ghdl,'-r','--std=08','--workdir='+str(BUILD/'ghdl'),'tb_memory','--assert-level=error'])
    for name,sources in [('audio',['rtl/platform/gg_audio.sv','tests/tb_audio.sv']),
                         ('sdram',['rtl/platform/gg_sdram.sv','tests/sdram_model.sv','tests/tb_sdram.sv'])]:
        run(name+'-compile',ivl_args+['-g2012','-s','tb_'+name,'-o',BUILD/('tb_'+name)]+sources)
        run(name,[vvp,BUILD/('tb_'+name)])
    engine=['build/gamegear_machine.v']+sorted(str(p.relative_to(ROOT)) for p in (ROOT/'rtl/generated/jt89').glob('*.v'))+['rtl/platform/gg_enables.sv']
    for name,extra in [('engine',[]),('sms_engine',['rtl/platform/gg_video.sv']),
                       ('soc',['rtl/platform/gg_audio.sv','rtl/platform/gg_video.sv',
                      'rtl/platform/sms_pause_guard.sv','rtl/platform/sega_rom_type.sv',
                      'rtl/platform/gamegear_soc.sv','rtl/platform/gg_sdram.sv','tests/sdram_model.sv'])]:
        sources=engine+extra+['tests/tb_'+name+'.sv']
        run(name+'-verilator-build',[verilator,'--binary','--timing','-Wno-fatal',
            '-MAKEFLAGS','VK_PCH_I_FAST= VK_PCH_I_SLOW=','--top-module','tb_'+name,
            '--Mdir',BUILD/('verilator_'+name),'-j','4']+sources)
        run(name,[BUILD/('verilator_'+name)/('Vtb_'+name)])
    if args.four_state:
        run('engine-four-state-compile',ivl_args+['-g2012','-s','tb_engine','-o',BUILD/'tb_engine']+engine+['tests/tb_engine.sv'])
        run('engine-four-state',[vvp,BUILD/'tb_engine'])
    report={'simulation_only':True,'hardware_tested':False,'checks':results}
    (BUILD/'test-results.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS all requested checks. These tests do not establish FPGA timing or hardware operation.')
if __name__=='__main__':main()
