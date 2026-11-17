#!/usr/bin/env python3
"""Measure repeatable native-renderer candidates against the recorded source frame."""
import itertools
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
out = root / 'video/review/calibration/variants'
out.mkdir(parents=True, exist_ok=True)
if len(sys.argv) != 2 or sys.argv[1] not in ('coarse', 'refine') or not os.environ.get('DISPLAY'):
    raise SystemExit('Usage: xvfb-run ... calibrate_builtin.py coarse|refine')
phase = sys.argv[1]
reference = np.asarray(Image.open(root / 'video/review/calibration/reference/render.png').convert('RGB'), dtype=np.float32)
regions = {
    'sky_left': (0, 0, 350, 200), 'sky_right': (1000, 0, 1280, 100),
    'wall': (800, 220, 1100, 350), 'cube': (450, 430, 600, 580),
    'floor_left': (0, 500, 400, 700), 'floor_right': (850, 500, 1250, 700),
    'metal_sphere': (350, 340, 400, 390),
}
if phase == 'coarse':
    cases = [dict(separate_background=1, sky_index=1, sun_energy=9.0 / np.pi, white=14.26024,
                  background_energy=environment, exposure=exposure)
             for environment, exposure in itertools.product((0.5, 1.0, 2.0), (0.4, 0.72, 1.0, 1.4))]
else:
    seed = json.loads((out / 'coarse-ranking.json').read_text())[0]['settings']
    cases = [dict(seed, sun_energy=sun, fog_density=fog, ssao_intensity=ao)
             for sun, fog, ao in itertools.product((1.5, 2.864789, 4.0), (0.0, 0.004, 0.01), (0.0, 1.0))]
ranking = []
for index, settings in enumerate(cases):
    stem = f'{phase}-{index:02d}'
    config = out / (stem + '.json')
    image = out / (stem + '.png')
    report = out / (stem + '-engine.json')
    log = out / (stem + '.log')
    config.write_text(json.dumps(settings, indent=2) + '\n')
    env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config', XDG_DATA_HOME='/tmp/saltline-godot-data',
               XDG_CACHE_HOME='/tmp/saltline-godot-cache')
    with log.open('w') as stream:
        command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
                   '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=render',
                   '--diffuse=lambert', '--frames=90', '--calibration=' + str(config), '--capture=' + str(image), '--report=' + str(report)]
        if subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=120).returncode:
            raise SystemExit('Godot failed: ' + stem)
    text = log.read_text(errors='replace')
    if 'SCRIPT ERROR' in text or '\nERROR:' in text:
        raise SystemExit('Godot reported errors: ' + stem)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    if actual.shape != reference.shape:
        raise SystemExit('Unexpected capture size')
    metrics = {}
    for name, (x0, y0, x1, y1) in regions.items():
        expected = reference[y0:y1, x0:x1]
        sample = actual[y0:y1, x0:x1]
        metrics[name] = {'mae_rgb8': round(float(np.mean(np.abs(sample - expected))), 3),
                         'reference_mean_rgb': np.round(expected.mean((0, 1)), 2).tolist(),
                         'actual_mean_rgb': np.round(sample.mean((0, 1)), 2).tolist()}
    score = round(float(np.mean([value['mae_rgb8'] for value in metrics.values()])), 3)
    ranking.append({'id': stem, 'settings': settings, 'score_equal_region_mae_rgb8': score, 'regions': metrics})
    print(stem, 'equal-region MAE', score, flush=True)
ranking.sort(key=lambda item: item['score_equal_region_mae_rgb8'])
(out / (phase + '-ranking.json')).write_text(json.dumps(ranking, ensure_ascii=False, indent=2) + '\n')
print('Best measured candidate:', ranking[0]['id'], ranking[0]['score_equal_region_mae_rgb8'], flush=True)
