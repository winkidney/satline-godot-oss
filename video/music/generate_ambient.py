#!/usr/bin/env python3
"""Generate the video's original, sample-free ambient bed."""
import wave
from pathlib import Path

import numpy as np

rate = 48000
seconds = 48
t = np.arange(rate * seconds, dtype=np.float64) / rate
chords = [(110.0, 130.81, 164.81), (98.0, 123.47, 146.83),
          (87.31, 110.0, 130.81), (98.0, 123.47, 164.81)]
sound = np.zeros_like(t)
for index, notes in enumerate(chords):
    center = 6 + index * 12
    distance = np.abs((t - center + seconds / 2) % seconds - seconds / 2)
    envelope = np.clip((9 - distance) / 6, 0, 1)
    envelope = envelope * envelope * (3 - 2 * envelope)
    for note in notes:
        note = round(note * seconds) / seconds
        sound += envelope * np.sin(2 * np.pi * note * t) / (len(notes) * len(chords))
sound *= 0.34 * (0.82 + 0.18 * np.sin(2 * np.pi * t / seconds))
stereo = np.column_stack((sound, sound)).clip(-1, 1)
out = Path(__file__).resolve().parents[1] / "editor/public/music/ambient.wav"
out.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(out), "wb") as wav:
    wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(rate)
    wav.writeframes((stereo * 32767).astype("<i2").tobytes())
print(out)
