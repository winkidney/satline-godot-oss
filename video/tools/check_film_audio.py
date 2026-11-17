#!/usr/bin/env python3
"""Check each private narration WAV against its position in the finished AAC mix."""
import argparse
import json
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy.signal import fftconvolve

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--timeline', type=Path, default=root / 'video/editor/.render-v5/timeline.json')
parser.add_argument('--mix', type=Path, default=root / 'video/editor/.render-v5/mix.m4a')
parser.add_argument('--output', type=Path, default=root / 'video/review/film-v5-audio-qc.json')
args = parser.parse_args()
timeline = json.loads(args.timeline.read_text())
results = []
for voice in timeline['narration']:
    begin = max(0, voice['start'] - .5)
    duration = voice['end'] - voice['start']
    if duration <= 0:
        raise ValueError('Invalid narration interval')
    raw = subprocess.check_output(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-ss', str(begin),
        '-i', str(args.mix), '-t', str(duration + 1), '-ac', '1', '-ar', '8000', '-f', 'f32le', '-'])
    mixed = np.frombuffer(raw, dtype='<f4').astype('float64')
    with wave.open(voice['src'], 'rb') as audio:
        if (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) != (48000, 1, 2):
            raise ValueError('Unexpected narration format')
        source = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').astype('float64')[::6] / 32768
    if not len(source) or len(mixed) < len(source):
        raise ValueError('Narration or mixed segment is incomplete')
    correlation = fftconvolve(mixed, source[::-1], mode='valid')
    index = int(np.argmax(np.abs(correlation)))
    energy = np.cumsum(np.r_[0, mixed * mixed])
    denominator = np.sqrt(np.dot(source, source) * (energy[index + len(source)] - energy[index]))
    if denominator <= 0:
        raise ValueError('Narration or mixed segment is silent')
    score = abs(correlation[index]) / denominator
    offset = 1000 * (index / 8000 - (voice['start'] - begin))
    results.append({'clip': Path(voice['src']).stem, 'offset_ms': round(offset, 2), 'correlation': round(float(score), 5)})
    if abs(offset) >= 100 or score <= .8:
        raise ValueError(f'Narration timing or correlation failed: {results[-1]}')
if not results:
    raise ValueError('No narration clips')
report = {'method': '8 kHz mono cross correlation; final AAC mix vs source WAV', 'count': len(results),
          'max_abs_offset_ms': max(abs(x['offset_ms']) for x in results),
          'min_correlation': min(x['correlation'] for x in results), 'segments': results}
args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(f"Checked {report['count']} clips; max offset {report['max_abs_offset_ms']} ms; minimum correlation {report['min_correlation']}")
