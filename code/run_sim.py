#!/usr/bin/env python3
"""Run Icarus regressions on Windows/Linux. No third-party Python packages."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
CORE = ['i2s_tx','note_table','adsr','osc_voice','oscillator_array',
        'note_alloc','mix_tree','synth_top']
SUITES = {
    'i2s_tx': ['i2s_tx'],
    'note_alloc': ['note_alloc'],
    'adsr': ['adsr'],
    'synth_top': CORE,
    'tone_test': ['i2s_tx','tone_test_top'],
    'synth_board': CORE + ['debounce','synth_board_top'],
    'led_ctrl_top': ['clk_div','debounce','pwm','led_ctrl_top'],
    'key_scan': ['debounce','key_scan'],
    'synth_board12': CORE + ['debounce','key_scan','synth_board12_top'],
    'key12_notes': ['debounce','key_scan'],
    'primer25k': CORE + ['debounce','key_scan',
                         '../boards/tang_primer25k/primer25k_top',
                         '../boards/tang_primer25k/primer25k_tone_top'],
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iverilog', default=shutil.which('iverilog'))
    parser.add_argument('--vvp', default=shutil.which('vvp'))
    parser.add_argument('--suite', choices=list(SUITES))
    parser.add_argument('--waves', action='store_true', help='write VCD waveforms (large)')
    args = parser.parse_args()
    if not args.iverilog:
        parser.error('iverilog not found; add it to PATH or pass --iverilog')
    iv = str(Path(args.iverilog).resolve())
    vvp = args.vvp or str(Path(iv).with_name('vvp.exe' if sys.platform=='win32' else 'vvp'))
    build = ROOT.parent/'build'/'sim'
    build.mkdir(parents=True, exist_ok=True)
    failed = []
    for name, sources in SUITES.items():
        if args.suite and args.suite != name:
            continue
        output = build/(name+'.out')
        command = [iv,'-g2005','-s','tb_'+name,'-o',str(output)]
        command += [str((ROOT/'rtl'/(s+'.v')).resolve()) for s in sources]
        command += [str(ROOT/'sim'/('tb_'+name+'.v'))]
        try:
            compiled = subprocess.run(command, cwd=build, capture_output=True, text=True,
                                      encoding='utf-8', errors='replace', timeout=60)
            if compiled.returncode:
                print(compiled.stdout+compiled.stderr)
                failed.append(name+' (compile)')
                continue
            run_command = [vvp,str(output)] + ([] if args.waves else ['-none'])
            run = subprocess.run(run_command, cwd=build, capture_output=True,
                                 text=True, encoding='utf-8', errors='replace', timeout=600)
            log = compiled.stdout+compiled.stderr+run.stdout+run.stderr
            (build/(name+'.log')).write_text(log,encoding='utf-8')
            bad = run.returncode or re.search(r'\[FAIL\]|\[ERROR\]|FATAL:|ERROR:', log)
            # A silent/early-exiting test must not pass just because exit status is 0.
            if not re.search(r'\[PASS\]', log):
                bad = True
            print(('FAIL' if bad else 'PASS')+': '+name)
            if bad:
                print(log)
                failed.append(name)
        except subprocess.TimeoutExpired:
            print('FAIL: '+name+' (timeout)')
            failed.append(name+' (timeout)')
    if failed:
        print('Failed suites: '+', '.join(failed))
        return 1
    print('ALL SIMULATIONS PASSED')
    return 0

if __name__ == '__main__':
    sys.exit(main())
