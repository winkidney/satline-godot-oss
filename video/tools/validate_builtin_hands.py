#!/usr/bin/env python3
"""Compare baked hand materials on the source glove pixels, not the background."""
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
out = root / 'video/review/calibration/hands'
out.mkdir(parents=True, exist_ok=True)
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
source_dir = root / 'video/review/calibration/source'
source = np.asarray(Image.open(source_dir / 'hands.png').convert('RGB'), dtype=np.float32)
state = json.loads((source_dir / 'hands.json').read_text())
base = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'source_grade': 1,
        'sky_red': 1, 'sky_green': 1, 'sky_blue': 1, 'ssao_intensity': 0, 'volumetric_density': 0, 'glow_intensity': 0,
        'sun_energy': 9.0 / np.pi, 'sun_angular_distance': 2.0, 'background_energy': 1.45,
        'exposure': float(state['exposure']) * float(state['adapt']['auto']) * 1.3 / 1.8}
mask = np.zeros(source.shape[:2], dtype=bool)
mask[140:640, 250:1030] = True
r, g, b = source[:, :, 0], source[:, :, 1], source[:, :, 2]
mask &= (r > 45) & (r > g * 1.08) & (r > b * 1.25)
assert mask.sum() > 10000, 'Source glove mask is unexpectedly small'
environment = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config', XDG_DATA_HOME='/tmp/saltline-godot-data',
                   XDG_CACHE_HOME='/tmp/saltline-godot-cache')
summary = {}
for name, atlas, normal, strength in [('vertex', 0, 0, 1), ('atlas', 1, 0, 1),
                                      ('normal-010', 1, 1, .1), ('normal-025', 1, 1, .25),
                                      ('normal-050', 1, 1, .5), ('atlas-normal', 1, 1, 1)]:
    settings = dict(base, arm_atlas=atlas, arm_normal=normal, arm_normal_strength=strength)
    config, image, report, log = [out / (name + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
    config.write_text(json.dumps(settings, indent=2) + '\n')
    command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=hands',
               '--diffuse=lambert', '--frames=120', '--calibration=' + str(config), '--capture=' + str(image), '--report=' + str(report)]
    with log.open('w') as stream:
        subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=180)
    text = log.read_text(errors='replace')
    if 'SCRIPT ERROR' in text or '\nERROR:' in text or json.loads(report.read_text())['warnings']:
        raise RuntimeError('Godot error in ' + name)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    summary[name] = {'mask_pixels': int(mask.sum()), 'glove_mae_rgb8': round(float(np.abs(actual[mask] - source[mask]).mean()), 3),
                     'source_mean_rgb8': np.round(source[mask].mean(axis=0), 2).tolist(),
                     'builtin_mean_rgb8': np.round(actual[mask].mean(axis=0), 2).tolist(), 'settings': settings}
    print(name, 'glove MAE', summary[name]['glove_mae_rgb8'], flush=True)
(out / 'measurements.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
