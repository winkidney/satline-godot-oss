#!/usr/bin/env python3
"""Check whether one background color correction helps several source views."""
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
source = root / 'video/review/calibration/source'
out = root / 'video/review/calibration/sky'
out.mkdir(parents=True, exist_ok=True)
environment = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
                   XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')
summary = {}
for name, tint in [('base', (1, 1, 1)), ('warm-1', (1.2, 1.05, .9)),
                   ('warm-2', (1.4, 1.1, .9)), ('warm-3', (1.1, 1, .8))]:
    errors = []
    for scene in ('ground', 'render', 'props', 'backdrop'):
        state = json.loads((source / (scene + '.json')).read_text())
        config = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'source_grade': 2,
                  'ssao_intensity': 0, 'ground_atlas': 0, 'volumetric_density': 0, 'glow_intensity': 0,
                  'sun_energy': 9.0 / np.pi, 'sun_angular_distance': 2.0, 'background_energy': 1.45,
                  'exposure': float(state['adapt']['auto']) * 1.3 / 1.8,
                  'sky_red': tint[0], 'sky_green': tint[1], 'sky_blue': tint[2]}
        stem = name + '-' + scene
        settings, image, report, log = [out / (stem + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
        settings.write_text(json.dumps(config, indent=2) + '\n')
        command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
                   '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=' + scene,
                   '--diffuse=lambert', '--frames=90', '--calibration=' + str(settings),
                   '--capture=' + str(image), '--report=' + str(report)]
        with log.open('w') as stream:
            subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
        if 'SCRIPT ERROR' in log.read_text(errors='replace') or json.loads(report.read_text())['warnings']:
            raise RuntimeError('Native renderer failed: ' + stem)
        reference = np.asarray(Image.open(source / (scene + '.png')).convert('RGB'), dtype=np.float32)
        actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
        # Upper corners contain sky in these four camera views, but not identical cloud states.
        regions = [(slice(30, 95), slice(20, 270)), (slice(30, 95), slice(970, 1230))]
        error = float(np.mean([np.abs(reference[y, x] - actual[y, x]).mean() for y, x in regions]))
        errors.append(error)
        print(stem, round(error, 3), flush=True)
    summary[name] = {'linear_rgb_multiplier': tint, 'sky_corner_mae_rgb8': round(float(np.mean(errors)), 3),
                     'per_scene_mae_rgb8': dict(zip(('ground', 'render', 'props', 'backdrop'), np.round(errors, 3).tolist())),
                     'note': 'Different cloud times and source bloom remain in the comparison.'}
(out / 'measurements.json').write_text(json.dumps(summary, indent=2) + '\n')
