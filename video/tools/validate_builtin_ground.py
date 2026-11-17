#!/usr/bin/env python3
"""Compare baked ground variants under the same source camera and lighting."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--refine', action='store_true')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
out = root / 'video/review/calibration/ground'
out.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config',
           XDG_DATA_HOME='/tmp/saltline-godot-data', XDG_CACHE_HOME='/tmp/saltline-godot-cache')
source = np.asarray(Image.open(root / 'video/review/calibration/source/ground.png').convert('RGB'), dtype=np.float32)
rough_source = np.fromfile(root / 'builtin-godot/assets/baked-ground/color-roughness.rgba8', dtype=np.uint8).reshape(2048, 2048, 4)[:, :, 3]
settings = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'source_grade': 2,
            'sky_red': 1, 'sky_green': 1, 'sky_blue': 1, 'ssao_intensity': 0, 'volumetric_density': 0, 'glow_intensity': 0,
            'sun_energy': 9.0 / np.pi, 'sun_angular_distance': 2.0, 'background_energy': 1.45,
            'exposure': 0.6 * 1.3 / 1.8, 'arm_atlas': 1}
summary = {}
cases = [('flat', 0, 0, True, 0, .5, 1), ('baked', 1, 0, True, 0, .5, 1),
         ('normal-025', 1, .25, True, 0, .5, 1), ('normal-050', 1, .5, True, 0, .5, 1),
         ('normal-100', 1, 1, True, 0, .5, 1), ('baked-no-ssr', 1, 0, False, 0, .5, 1)]
cases += [('floor-%03d' % floor, 1, 1, True, floor, .5, 1) for floor in (25, 51, 89, 128)]
cases += [('spec-%03d' % spec, 1, 1, True, 51, spec / 100.0, 1) for spec in (10, 25)]
if args.refine:
    cases = [('refine-%03d-%03d' % (spec, albedo), 1, 1, True, 51, spec / 100.0, albedo / 100.0)
             for spec in (20, 25, 30, 35) for albedo in (100, 150, 200)]
rough_path = root / 'builtin-godot/assets/baked-ground/roughness.r8'
previous = rough_path.read_bytes()
try:
    for name, atlas, normal, reflection, floor, specular, albedo in cases:
        np.maximum(rough_source, floor).astype(np.uint8).tofile(root / 'builtin-godot/assets/baked-ground/roughness.r8')
        config = settings | {'ground_atlas': atlas, 'ground_normal_strength': normal, 'ground_specular': specular, 'ground_albedo': albedo}
        config_file, image_file, report_file, log_file = [out / (name + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
        config_file.write_text(json.dumps(config, indent=2) + '\n')
        command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
                   '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=ground',
                   '--diffuse=lambert', '--frames=120', '--ssr' if reflection else '--no-ssr',
                   '--calibration=' + str(config_file), '--capture=' + str(image_file), '--report=' + str(report_file)]
        with log_file.open('w') as stream:
            subprocess.run(command, env=env, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
        log, report = log_file.read_text(errors='replace'), json.loads(report_file.read_text())
        if 'SCRIPT ERROR' in log or '\nERROR:' in log or report['warnings']:
            raise RuntimeError('Native rendering failed: ' + name)
        actual = np.asarray(Image.open(image_file).convert('RGB'), dtype=np.float32)
        if actual.shape != source.shape:
            raise RuntimeError('Image dimensions differ')
        crop = np.abs(actual[420:700, 50:1230] - source[420:700, 50:1230])
        summary[name] = {'ground_crop_mae_rgb8': round(float(crop.mean()), 3), 'roughness_floor_rgb8': floor, 'settings': config,
                         'ssr': reflection, 'note': 'Crop includes lighting, rain and geometry; source frames are not synchronized.'}
        print(name, summary[name]['ground_crop_mae_rgb8'], flush=True)
finally:
    rough_path.write_bytes(previous)
(out / ('measurements-refined.json' if args.refine else 'measurements.json')).write_text(json.dumps(summary, indent=2) + '\n')
