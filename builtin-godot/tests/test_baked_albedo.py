#!/usr/bin/env python3
"""Check the two source tint formulas and retained mip levels against source bytes."""
import json
import math
import struct
from pathlib import Path

project = Path(__file__).resolve().parents[1]
source = project.parent / 'saltline-godot'
manifest = json.loads((project / 'assets/baked-albedo/manifest.json').read_text())
catalog = json.loads((source / 'assets/catalog/materials-full/catalog.json').read_text())
textures = {item['id']: item for item in catalog['textures']}
checked = set()
for material in catalog['materials']:
    props = material['props']
    mode = int(props.get('defines', {}).get('SL_TINT', 0))
    if mode not in (1, 2) or mode in checked:
        continue
    texture = textures[props['map']['$texture']]
    original = (source / texture['godot_source_mip_file'].removeprefix('res://')).read_bytes()
    entry = manifest[material['id']]
    baked = (project / 'assets/baked-albedo' / entry['file']).read_bytes()
    width, height = entry['width'], entry['height']
    byte_offset = half_offset = 0
    while True:
        count = width * height
        for pixel in (0, count // 2, count - 1):
            rgba = original[byte_offset + pixel * 4:byte_offset + pixel * 4 + 4]
            values = [value / 255 for value in rgba]
            rgb = [value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4 for value in values[:3]]
            base = props['color']
            if mode == 1:
                expected = [rgb[i] + base[i] * values[3] for i in range(3)]
            else:
                luminance = min(1.35, max(.55, sum(rgb) * .3333 / .19))
                expected = [rgb[i] * (1 - values[3] * .96) + base[i] * luminance * values[3] * .96 for i in range(3)]
            actual = struct.unpack_from('<4e', baked, half_offset + pixel * 8)
            assert all(math.isclose(actual[i], expected[i], abs_tol=.002) for i in range(3))
            assert actual[3] == 1.0
        byte_offset += count * 4
        half_offset += count * 8
        if not entry['mipmaps'] or (width == 1 and height == 1): break
        width, height = max(1, width // 2), max(1, height // 2)
    assert byte_offset == len(original) and half_offset == len(baked)
    checked.add(mode)
assert checked == {1, 2}
print('Tint 1 and 2 match source formulas at sampled texels across all mip levels.')
