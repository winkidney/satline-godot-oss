#!/usr/bin/env python3
"""Compare native glow and volumetric fog without replacing the stock renderer."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--scene', choices=('level', 'backdrop', 'ground'), default='level')
parser.add_argument('--refine', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
out = root / 'video/review/calibration/atmosphere' / (args.scene + ('-refine' if args.refine else ''))
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
           XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')
source_dir = root / 'video/review/calibration/source'
reference = np.asarray(Image.open(source_dir / (args.scene + '.png')).convert('RGB'), dtype=np.float32)
state = json.loads((source_dir / (args.scene + '.json')).read_text())
base = {'exposure': state['adapt']['auto'] * 1.3 / 1.8}
cases = [('none', 0, 0), ('glow-03', 0, .3), ('glow-07', 0, .7),
         ('fog-005', .005, 0), ('fog-020', .02, 0), ('fog-005-glow-03', .005, .3)]
if args.refine:
    cases = [('fog-020-glow-07', .02, .7), ('fog-040', .04, 0),
             ('fog-040-glow-07', .04, .7), ('fog-080-glow-07', .08, .7)]
summary = {}
for name, fog, glow in cases:
    settings = base | {'volumetric_density': fog, 'glow_intensity': glow}
    config, image, report, log = [out / (name + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
    config.write_text(json.dumps(settings, indent=2) + '\n')
    command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=' + args.scene,
               '--frames=120', '--calibration=' + str(config), '--capture=' + str(image), '--report=' + str(report)]
    with log.open('w') as stream:
        subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=180)
    text, result = log.read_text(errors='replace'), json.loads(report.read_text())
    if 'SCRIPT ERROR' in text or '\nERROR:' in text or result['warnings']:
        raise RuntimeError('Native atmosphere test failed: ' + name)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    if actual.shape != reference.shape:
        raise RuntimeError('Image dimensions differ')
    summary[name] = {'central_mae_rgb8': round(float(np.abs(actual[100:650, 250:1030] - reference[100:650, 250:1030]).mean()), 3),
                     'full_mae_rgb8': round(float(np.abs(actual - reference).mean()), 3),
                     'fps': result['fps'], 'settings': settings,
                     'note': 'Different cloud and animation states remain in separate captures.'}
    print(args.scene, name, summary[name]['central_mae_rgb8'], flush=True)
(out / 'measurements.json').write_text(json.dumps(summary, indent=2) + '\n')
