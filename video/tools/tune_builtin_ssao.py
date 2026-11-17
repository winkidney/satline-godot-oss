#!/usr/bin/env python3
"""Fit Godot's built-in SSAO to the source weapon's occluded magazine."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--channel', type=float, choices=(0, 1), default=0)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
out = root / 'video/review/calibration' / ('ssao' if args.channel == 0 else 'ssao-channel-1')
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
           XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')
reference = np.asarray(Image.open(root / 'video/review/calibration/source/weapon.png').convert('RGB'), dtype=np.float32)
base = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'source_grade': 2,
        'sky_red': 1.2, 'sky_green': 1.05, 'sky_blue': .9, 'sun_energy': 9.0 / np.pi,
        'sun_angular_distance': 2.0, 'background_energy': 1.45, 'exposure': 0.706 * 1.3 / 1.8, 'arm_atlas': 1}
cases = [(radius, intensity, 1.0) for radius in (.5, .9, 1.5) for intensity in (1, 2, 4, 8)]
cases += [(.9, 4, 0), (.9, 4, .5)]
summary = {}
for radius, intensity, direct in cases:
    name = 'r%03d-i%03d-d%03d' % (round(radius * 100), round(intensity * 10), round(direct * 100))
    settings = base | {'ssao_radius': radius, 'ssao_intensity': intensity, 'ssao_light_affect': direct,
                       'ssao_ao_channel_affect': args.channel}
    config, image, report, log = [out / (name + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
    config.write_text(json.dumps(settings, indent=2) + '\n')
    command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
               '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=weapon',
               '--diffuse=lambert', '--frames=120', '--calibration=' + str(config),
               '--capture=' + str(image), '--report=' + str(report)]
    with log.open('w') as stream:
        subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
    text, result = log.read_text(errors='replace'), json.loads(report.read_text())
    if 'SCRIPT ERROR' in text or '\nERROR:' in text or result['warnings']:
        raise RuntimeError('Native SSAO test failed: ' + name)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    if actual.shape != reference.shape:
        raise RuntimeError('Image dimensions differ')
    def error(y, x):
        return round(float(np.abs(reference[y, x] - actual[y, x]).mean()), 3)
    summary[name] = {'magazine_mae_rgb8': error(slice(450, 535), slice(655, 730)),
                     'weapon_mae_rgb8': error(slice(210, 655), slice(70, 1210)),
                     'sample_rgb8_at_690_480': actual[480, 690].astype(int).tolist(), 'settings': settings,
                     'note': 'Original screen-space AO depends on exposure; screenshots are separate recordings.'}
    print(name, summary[name]['magazine_mae_rgb8'], summary[name]['sample_rgb8_at_690_480'], flush=True)
(out / 'measurements.json').write_text(json.dumps(summary, indent=2) + '\n')
