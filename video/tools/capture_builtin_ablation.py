#!/usr/bin/env python3
"""Measure native and source sun-only, environment-only and combined illumination."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--scene', choices=('render', 'weapon'), default='render')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
out = root / 'video/review/calibration/ablation'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
base = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'exposure': 1.3 / 1.8, 'source_grade': 1,
        'sky_red': 1, 'sky_green': 1, 'sky_blue': 1, 'ssao_intensity': 0}
cases = {'full': (9.0 / np.pi, 2.0), 'sun': (9.0 / np.pi, 0.0), 'ibl': (0.0, 2.0)}
regions = {'wall': (800, 220, 1100, 350), 'cube': (450, 430, 600, 580),
           'floor_left': (0, 500, 400, 700), 'floor_right': (850, 500, 1250, 700),
           'metal_smooth': (345, 345, 400, 393), 'metal_rough': (470, 350, 500, 385)}
if args.scene == 'weapon':
    base.update(source_grade=2, arm_atlas=1, sky_red=1.2, sky_green=1.05, sky_blue=.9)
    cases = {'full': (9.0 / np.pi, 1.45), 'sun': (9.0 / np.pi, 0.0), 'ibl': (0.0, 1.45)}
    regions = {'magazine': (670, 465, 710, 510), 'body': (660, 365, 720, 410)}
env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config', XDG_DATA_HOME='/tmp/saltline-godot-data',
           XDG_CACHE_HOME='/tmp/saltline-godot-cache')
results = {}
for name, (sun, ibl) in cases.items():
    settings = dict(base, sun_energy=sun, background_energy=ibl)
    prefix = 'builtin-grade-' + (args.scene + '-' if args.scene != 'render' else '') + name
    config = out / (prefix + '-settings.json')
    image = out / (prefix + '.png')
    report = out / (prefix + '-engine.json')
    log = out / (prefix + '.log')
    config.write_text(json.dumps(settings, indent=2) + '\n')
    command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=' + args.scene,
               '--diffuse=lambert', '--frames=90', '--calibration=' + str(config), '--capture=' + str(image), '--report=' + str(report)]
    with log.open('w') as stream:
        subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
    if 'SCRIPT ERROR' in log.read_text() or '\nERROR:' in log.read_text():
        raise RuntimeError('Godot reported errors in ' + name)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32) / 255
    expected = np.asarray(Image.open(out / ('source-' + (args.scene + '-' if args.scene != 'render' else '') + name + '.png')).convert('RGB'), dtype=np.float32) / 255
    metrics = {}
    for label, (x0, y0, x1, y1) in regions.items():
        a, b = actual[y0:y1, x0:x1], expected[y0:y1, x0:x1]
        def summary(value):
            linear = np.where(value <= .04045, value / 12.92, ((value + .055) / 1.055) ** 2.4)
            luminance = linear @ np.array([.2126, .7152, .0722])
            return {'mean_rgb8': np.round(value.mean((0, 1)) * 255, 2).tolist(),
                    'linear_luminance_p10_p50_p90': np.round(np.percentile(luminance, [10, 50, 90]), 5).tolist()}
        metrics[label] = {'source': summary(b), 'builtin': summary(a),
                          'mae_rgb8': round(float(np.abs(a-b).mean() * 255), 3)}
    results[name] = {'settings': settings, 'regions': metrics}
    print(name, 'region MAE', {key: value['mae_rgb8'] for key, value in metrics.items()}, flush=True)
(out / ('measurements-grade-' + args.scene + '.json' if args.scene != 'render' else 'measurements-grade.json')).write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
