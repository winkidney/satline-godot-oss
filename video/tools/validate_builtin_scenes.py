#!/usr/bin/env python3
"""Capture all native showcases and compare them to separately captured source frames."""
import argparse
import json
import os
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument('--grade', type=int, choices=(1, 2), default=1)
parser.add_argument('--arm-atlas', action='store_true')
parser.add_argument('--ground-atlas', action='store_true')
parser.add_argument('--ssao-intensity', type=float, default=0)
parser.add_argument('--ssao-radius', type=float, default=.9)
parser.add_argument('--glow', type=float, default=0)
parser.add_argument('--volumetric-density', type=float, default=0)
parser.add_argument('--output', default='fitted')
parser.add_argument('--scene')
parser.add_argument('--defaults', action='store_true', help='Test the ordinary project launch defaults')
args = parser.parse_args()
if Path(args.output).name != args.output:
    parser.error('--output must be a directory name')
root = Path(__file__).resolve().parents[2]
godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
assert godot, 'Set GODOT_BIN or put Godot on PATH'
assert os.environ.get('DISPLAY'), 'Run under an isolated X display'
source = root / 'video/review/calibration/source'
out = root / 'video/review/calibration' / args.output
out.mkdir(parents=True, exist_ok=True)
regions = {
    'mats': (190, 210, 1040, 505), 'props': (80, 240, 1200, 510),
    'render': (260, 300, 1050, 610), 'ground': (50, 300, 1230, 700),
    'level': (40, 240, 1240, 690), 'backdrop': (60, 200, 1220, 610),
    'enemies': (250, 220, 1050, 570), 'weapon': (70, 210, 1210, 655),
    'hands': (180, 130, 1100, 690), 'fx': (100, 230, 1180, 670),
}
if args.scene and args.scene not in regions:
    parser.error('unknown scene')
environment = dict(os.environ, XDG_CONFIG_HOME='/tmp/saltline-godot-config', XDG_DATA_HOME='/tmp/saltline-godot-data',
                   XDG_CACHE_HOME='/tmp/saltline-godot-cache')
summary = {}
for scene, (x0, y0, x1, y1) in regions.items():
    if args.scene and args.scene != scene:
        continue
    reference_state = json.loads((source / (scene + '.json')).read_text())
    source_exposure = float(reference_state['exposure']) * float(reference_state['adapt']['auto'])
    settings = {'separate_background': 1, 'sky_index': 1, 'white': 14.26024, 'source_grade': args.grade,
                'sun_energy': 9.0 / np.pi, 'sun_angular_distance': 2.0,
                'background_energy': 1.45, 'exposure': source_exposure * 1.3 / 1.8,
                'sky_red': 1.2, 'sky_green': 1.05, 'sky_blue': .9,
                'ssao_intensity': args.ssao_intensity, 'ssao_radius': args.ssao_radius,
                'glow_intensity': args.glow, 'volumetric_density': args.volumetric_density,
                'ssao_light_affect': 1, 'ssao_ao_channel_affect': 1,
                'arm_atlas': int(args.arm_atlas), 'arm_normal': 0, 'ground_atlas': int(args.ground_atlas),
                'ground_normal_strength': 1, 'ground_specular': .25, 'ground_albedo': 2}
    config, image, report, log = [out / (scene + suffix) for suffix in ('.json', '.png', '-engine.json', '.log')]
    config.write_text(json.dumps(settings, indent=2) + '\n')
    command = [godot, '--audio-driver', 'Dummy', '--display-driver', 'x11',
            '--rendering-driver', 'vulkan', '--path', str(root / 'builtin-godot'), '--', '--scene=' + scene,
            '--frames=120', '--capture=' + str(image), '--report=' + str(report)]
    if not args.defaults:
        command += ['--diffuse=lambert', '--calibration=' + str(config)]
    with log.open('w') as stream:
        subprocess.run(command, env=environment, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=120)
    text = log.read_text(errors='replace')
    engine = json.loads(report.read_text())
    if args.defaults:
        settings = engine['calibration']
        config.write_text(json.dumps(settings, indent=2) + '\n')
    if 'SCRIPT ERROR' in text or '\nERROR:' in text or engine['warnings']:
        raise RuntimeError('Native renderer error or warning in ' + scene)
    reference = np.asarray(Image.open(source / (scene + '.png')).convert('RGB'), dtype=np.float32)
    actual = np.asarray(Image.open(image).convert('RGB'), dtype=np.float32)
    initial = np.asarray(Image.open(root / 'builtin-godot/evidence' / (scene + '.png')).convert('RGB'), dtype=np.float32)
    if actual.shape != reference.shape or initial.shape != reference.shape:
        raise RuntimeError('Unexpected image dimensions')
    def metrics(sample):
        crop, target = sample[y0:y1, x0:x1], reference[y0:y1, x0:x1]
        return {'full_mae_rgb8': round(float(np.abs(sample-reference).mean()), 3),
                'subject_mae_rgb8': round(float(np.abs(crop-target).mean()), 3),
                'subject_mean_rgb8': np.round(crop.mean((0, 1)), 2).tolist()}
    summary[scene] = {'source_exposure': source_exposure, 'subject_rect': [x0, y0, x1, y1],
                      'source_mean_rgb8': np.round(reference[y0:y1, x0:x1].mean((0, 1)), 2).tolist(),
                      'initial': metrics(initial), 'fitted': metrics(actual), 'settings': settings,
                      'note': 'Descriptive image error, not parity: captures differ in time and native effects are approximate.'}
    print(scene, 'subject MAE', summary[scene]['initial']['subject_mae_rgb8'], '→', summary[scene]['fitted']['subject_mae_rgb8'], flush=True)
(out / 'comparison.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
