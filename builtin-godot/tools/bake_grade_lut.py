#!/usr/bin/env python3
"""Bake the source's static display grade into a native Godot 3D LUT."""
from pathlib import Path
import numpy as np

size = 65
axis = (np.arange(size, dtype=np.float32) + .5) / size
axis[0], axis[-1] = 0.0, 1.0
red, green = np.meshgrid(axis, axis)
layers = []
for blue in axis:
    srgb = np.stack((red, green, np.full_like(red, blue)), axis=-1)
    color = np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)
    luminance = color @ np.array([.2126, .7152, .0722], dtype=np.float32)
    t = np.clip((luminance - .03) / (.55 - .03), 0, 1)
    t = t * t * (3 - 2 * t)
    shadow = np.array([.80, 1.01, 1.13], dtype=np.float32)
    highlight = np.array([1.07, 1.0, .90], dtype=np.float32)
    color *= shadow + (highlight - shadow) * t[..., None]
    color = .78 * color + .22 * color * color * (3 - 2 * color)
    color = np.clip(color * .988 + np.array([.006, .0085, .011], dtype=np.float32), 0, 1)
    graded = np.where(color <= .0031308, color * 12.92, 1.055 * color ** (1 / 2.4) - .055)
    layers.append(np.concatenate((graded, np.ones((*graded.shape[:2], 1), dtype=np.float32)), axis=-1).astype('<f2').tobytes())
target = Path(__file__).resolve().parents[1] / 'assets/source-grade-65.rgba16f'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(b''.join(layers))
print('Wrote', target.name, 'with', size, 'slices')
