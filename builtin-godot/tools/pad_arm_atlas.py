#!/usr/bin/env python3
"""Fill each triangle tile with nearest surface texels to prevent atlas seams."""
import sys
from pathlib import Path
import numpy as np
from scipy.ndimage import distance_transform_edt

if len(sys.argv) != 3:
    raise SystemExit('Usage: pad_arm_atlas.py GEOMETRY_ID TRIANGLE_COUNT')
identifier, count = sys.argv[1], int(sys.argv[2])
directory = Path(__file__).resolve().parents[1] / 'assets/baked-arms'
size, cell, columns = 2048, 16, 128
color_path, normal_path = [directory / (identifier + '-' + name + '.raw') for name in ('color', 'normal')]
color = np.frombuffer(color_path.read_bytes(), dtype=np.uint8).reshape(size, size, 4).copy()
normal = np.frombuffer(normal_path.read_bytes(), dtype=np.uint8).reshape(size, size, 4).copy()
for triangle in range(count):
    y, x = divmod(triangle, columns)
    crop = np.s_[y*cell:(y+1)*cell, x*cell:(x+1)*cell]
    mask = normal[crop][:, :, 3] != 0
    if not mask.any():
        raise RuntimeError(f'No atlas texels for triangle {triangle}')
    nearest = distance_transform_edt(~mask, return_distances=False, return_indices=True)
    for pixels in (color, normal):
        tile = pixels[crop]
        tile[:] = tile[nearest[0], nearest[1]]
for pixels, name in ((color, 'color'), (normal, 'normal')):
    (directory / (identifier + '-' + name + '.rgba8')).write_bytes(pixels.tobytes())
print('Padded', count, 'triangle tiles')
