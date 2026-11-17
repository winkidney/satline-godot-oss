#!/usr/bin/env python3
"""Flag narration segments for listening; automatic recognition is not approval."""
import argparse
import ctypes
import ctypes.util
import difflib
import json
import re
import unicodedata
from pathlib import Path

import whisper

parser = argparse.ArgumentParser()
parser.add_argument('project', type=Path)
parser.add_argument('--manifest', default='narration-jobs.json')
parser.add_argument('--output', default='production-asr.json')
args = parser.parse_args()
project = args.project.resolve()
jobs = json.loads((project / args.manifest).read_text())
model = whisper.load_model('base', device='cuda')
library = ctypes.util.find_library('opencc')
converter = ctypes.CDLL(library) if library else None
handle = None
if converter:
    converter.opencc_open.argtypes=[ctypes.c_char_p];converter.opencc_open.restype=ctypes.c_void_p
    converter.opencc_convert_utf8.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t]
    converter.opencc_convert_utf8.restype=ctypes.c_void_p
    converter.opencc_convert_utf8_free.argtypes=[ctypes.c_void_p]
    handle=converter.opencc_open(b't2s.json')
    if handle==ctypes.c_void_p(-1).value:handle=None
if not handle:print('OpenCC unavailable; traditional and simplified characters may reduce scores.',flush=True)
def normal(text):
    if handle:
        converted=converter.opencc_convert_utf8(handle,text.encode(),ctypes.c_size_t(-1))
        if converted:
            text=ctypes.string_at(converted).decode();converter.opencc_convert_utf8_free(converted)
    return re.sub(r'[^\w\u4e00-\u9fff]', '', unicodedata.normalize('NFKC', text).lower())

results = []
for job in jobs:
    wav = project / job['completed_output'] / 'steps/delivery/attempt-001/delivery.wav'
    heard = model.transcribe(str(wav), language='zh', verbose=None)['text']
    score = difflib.SequenceMatcher(None, normal(job['text']), normal(heard)).ratio()
    results.append({'id':job['id'],'score':round(score,3),'recognized':heard})
    print(job['id'],round(score,3),flush=True)
    out = project / args.output
    out.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n');out.chmod(0o600)
print(f"{sum(x['score']<.75 for x in results)} of {len(results)} segments need a closer listen; recognition is only a screening tool.")
