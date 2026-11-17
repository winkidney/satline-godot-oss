#!/usr/bin/env python3
"""Check RGB samples through the recorded-source, shot, concat and final stages."""
import argparse
import io
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

root = Path(__file__).resolve().parents[2]
version = int(json.loads((root / 'video/editor/src/film-plan.json').read_text())['version'])
work = root / f'video/editor/.render-v{version}'
parser = argparse.ArgumentParser()
parser.add_argument('--shots-only', action='store_true')
parser.add_argument('--output', type=Path, default=root / f'video/review/film-v{version}-color-qc.json')
args = parser.parse_args()
timeline = json.loads((work / 'timeline.json').read_text())

def shot_index(**fields):
    return next(i for i, shot in enumerate(timeline['shots'])
                if all(shot.get(k) == v for k, v in fields.items()) and shot['frames'] > 120)

def frame(path, seconds, filtergraph=None):
    command = ['ffmpeg', '-v', 'error', '-ss', str(seconds), '-i', str(path)]
    if filtergraph:
        command += ['-vf', filtergraph]
    command += ['-frames:v', '1', '-f', 'image2pipe', '-vcodec', 'png', '-']
    return np.asarray(Image.open(io.BytesIO(subprocess.check_output(command))).convert('RGB'), dtype=np.int16)

def stats(a, b):
    difference = b.astype(np.int16) - a.astype(np.int16)
    return {'mae_rgb8': round(float(np.abs(difference).mean()), 3),
            'mean_rgb_drift': [round(float(x), 3) for x in difference.mean(axis=(0, 1))]}

source_dir = root / 'video/recordings/showcases'
original_props = shot_index(scene='props', left='original', right='replica')
builtin_props = shot_index(scene='props', left='replica', right='builtin')
cases = [('original', 'props.webm', 'pc', 'bt709', 'bt709', original_props, 8),
         ('replica', 'props.mp4', 'tv', 'bt601', 'bt470bg', original_props, 968),
         ('builtin-calibrated', 'props.mp4', 'pc', 'bt601', 'bt470bg', builtin_props, 968)]
raw = []
for folder, name, input_range, matrix, space, index, x in cases:
    graph = (f'setparams=range={input_range}:colorspace={space},'
             f'scale=944:531:in_range={input_range}:in_color_matrix={matrix}:out_range=pc,format=rgb24')
    source = frame(source_dir / folder / name, 2.2, graph)[30:500, 20:920]
    shot = frame(work / f'shot-{index:03d}.mp4', 2)[125:595, x+20:x+920]
    item = {'source': folder, **stats(source, shot)}
    if item['mae_rgb8'] > 4:
        raise ValueError(f'Source to shot mismatch: {item}')
    raw.append(item)

report = {'method': 'RGB8 crops; source and output decoded separately; not a cross-engine accuracy score',
          'source_to_shot': raw}
if not args.shots_only:
    stages = []
    indices = (1, 5, original_props, builtin_props, shot_index(single='pbr'),
               shot_index(scene='render', left='original', right='replica'), len(timeline['shots']) - 2,
               len(timeline['shots']) - 1)
    for index in dict.fromkeys(indices):
        position = (timeline['shots'][index]['start_frame'] + 120) / 60
        shot = frame(work / f'shot-{index:03d}.mp4', 1.999)[150:590, 450:1350]
        picture = frame(work / 'picture.mp4', position - .001)[150:590, 450:1350]
        final = frame(root / 'video/final.mp4', position - .001)[150:590, 450:1350]
        copied, encoded = stats(shot, picture), stats(picture, final)
        if copied['mae_rgb8'] > 1 or encoded['mae_rgb8'] > 4 or max(map(abs, encoded['mean_rgb_drift'])) > 2:
            raise ValueError(f'Color drift at shot {index}: {copied}, {encoded}')
        stages.append({'shot': index, 'shot_to_concat': copied, 'concat_to_final': encoded})
    report['stages'] = stages
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(f"Checked {len(raw)} source samples" + (f" and {len(report['stages'])} final samples" if 'stages' in report else ''))
