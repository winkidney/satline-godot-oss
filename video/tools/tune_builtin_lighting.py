#!/usr/bin/env python3
"""Fit isolated native sun or IBL against the equivalent source ablation frame."""
import itertools
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

if len(sys.argv) != 2 or sys.argv[1] not in ('sun', 'ibl', 'ibl-fine') or not os.environ.get('DISPLAY'):
    raise SystemExit('Usage: xvfb-run ... tune_builtin_lighting.py sun|ibl|ibl-fine')
mode = sys.argv[1]
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
out = root / 'video/review/calibration/lighting'
out.mkdir(parents=True, exist_ok=True)
reference_kind = 'ibl' if mode == 'ibl-fine' else mode
reference = np.asarray(Image.open(root / f'video/review/calibration/ablation/source-{reference_kind}.png').convert('RGB'), dtype=np.float32)
regions = {'wall': (800, 220, 1100, 350), 'cube': (450, 430, 600, 580),
           'floor_left': (0, 500, 400, 700), 'floor_right': (850, 500, 1250, 700),
           'metal_smooth': (345, 345, 400, 393), 'metal_rough': (470, 350, 500, 385)}
base = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'exposure': 1.3 / 1.8, 'source_grade': 1,
        'sky_red': 1, 'sky_green': 1, 'sky_blue': 1, 'ssao_intensity': 0}
if mode in ('ibl', 'ibl-fine'):
    values = (.25, .5, .75, 1.0, 1.25, 1.5, 2.0, 2.5) if mode == 'ibl' else tuple(round(1.30 + i * .05, 2) for i in range(9))
    candidates = [dict(base, sun_energy=0.0, background_energy=value) for value in values]
else:
    candidates = [dict(base, background_energy=0.0, sun_energy=sun, sun_angular_distance=angle)
                  for sun, angle in itertools.product((1.43, 2.864789, 4.3, 5.73), (0, .5, 2, 5))]
environment = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config', XDG_DATA_HOME='/tmp/saltline-godot-data',
                   XDG_CACHE_HOME='/tmp/saltline-godot-cache')
ranking = []
for index, settings in enumerate(candidates):
    stem = f'{mode}-{index:02d}'
    config, image, report, log = [out / (stem + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
    config.write_text(json.dumps(settings, indent=2) + '\n')
    args = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
            '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=render',
            '--diffuse=lambert', '--frames=90', '--calibration=' + str(config), '--capture=' + str(image), '--report=' + str(report)]
    with log.open('w') as stream:
        subprocess.run(args, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
    content = log.read_text(errors='replace')
    if 'SCRIPT ERROR' in content or '\nERROR:' in content:
        raise RuntimeError('Native renderer error: ' + stem)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    if actual.shape != reference.shape: raise RuntimeError('Unexpected capture size')
    metrics = {}
    for name, (x0, y0, x1, y1) in regions.items():
        a, b = actual[y0:y1, x0:x1], reference[y0:y1, x0:x1]
        metrics[name] = round(float(np.abs(a - b).mean()), 3)
    score = round(float(np.mean(list(metrics.values()))), 3)
    ranking.append({'id': stem, 'settings': settings, 'equal_region_mae_rgb8': score, 'regions': metrics})
    print(stem, score, metrics, flush=True)
ranking.sort(key=lambda item: item['equal_region_mae_rgb8'])
(out / (mode + '-ranking.json')).write_text(json.dumps(ranking, ensure_ascii=False, indent=2) + '\n')
print('Best isolated candidate:', ranking[0]['id'], ranking[0]['equal_region_mae_rgb8'], flush=True)
