#!/usr/bin/env python3
"""Verify source provenance and the calibrated native roughness map."""
import hashlib
import json
from pathlib import Path

import numpy as np

root = Path(__file__).resolve().parents[2]
assets = root / 'builtin-godot/assets/baked-ground'
manifest = json.loads((assets / 'manifest.json').read_text())
for name, key, size in [('color-roughness.rgba8', 'color-roughness_sha256', 2048 * 2048 * 4),
                        ('normal.rgba8', 'normal_sha256', 2048 * 2048 * 4),
                        ('roughness.r8', 'roughness_sha256', 2048 * 2048)]:
    data = (assets / name).read_bytes()
    assert len(data) == size and hashlib.sha256(data).hexdigest() == manifest[key], name
source = (root / 'artifact-rendering-study/source/saltline.original.html').read_bytes()
assert hashlib.sha256(source).hexdigest() == manifest['html_sha256']
color = np.fromfile(assets / 'color-roughness.rgba8', np.uint8).reshape(2048, 2048, 4)
roughness = np.fromfile(assets / 'roughness.r8', np.uint8).reshape(2048, 2048)
assert np.array_equal(roughness, np.maximum(color[:, :, 3], manifest['roughness_floor_rgb8']))
assert color[:, :, :3].std() > 10 and roughness.std() > 10
assert abs(manifest['time'] - 5) < 0.01 and manifest['wet'] == 1
print('Baked ground provenance and roughness checks passed')
