#!/usr/bin/env python3
"""Provide silent timing placeholders when private narration is unavailable."""
import json
import wave
from pathlib import Path

editor=Path(__file__).resolve().parent.parent
media=json.loads((editor/'src/media.json').read_text())
created=0
for segment in media['narration']:
    path=editor/'public'/segment['src']
    if path.exists():continue
    path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    with wave.open(str(path),'wb') as output:
        output.setnchannels(1);output.setsampwidth(2);output.setframerate(48000)
        output.writeframes(b'\0\0'*round((segment['end']-segment['start'])*48000))
    path.chmod(0o600);created+=1
print(f'Created {created} silent placeholders; existing audio was not replaced.')
