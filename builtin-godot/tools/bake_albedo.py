#!/usr/bin/env python3
"""Bake static source tint rules into native Godot albedo textures, retaining HDR mip levels."""
import hashlib
import json
from pathlib import Path

import numpy as np

project = Path(__file__).resolve().parents[1]
source = project.parent / 'saltline-godot'
output = project / 'assets/baked-albedo'
output.mkdir(parents=True, exist_ok=True)
inputs = [source / 'assets/prepared/scene.json'] + [source / 'assets/catalog' / name / 'catalog.json'
          for name in ('materials-full', 'props', 'render', 'ground')]
manifest = {}
cache = {}
for path in inputs:
    data = json.loads(path.read_text())
    textures = {entry['id']: entry for entry in data['textures']}
    for material in data['materials']:
        props = material.get('props', {})
        mode = int(props.get('defines', {}).get('SL_TINT', 0))
        if mode not in (1, 2):
            continue
        reference = props.get('map')
        if not isinstance(reference, dict):
            raise ValueError('Tint material has no albedo map: ' + material['id'])
        texture = textures[reference['$texture']]
        if texture.get('colorSpace') != 'srgb':
            raise ValueError('Unexpected tint texture color space: ' + material['id'])
        source_file = source / texture['godot_source_mip_file'].removeprefix('res://')
        if source_file not in cache:
            raw = source_file.read_bytes()
            cache[source_file] = (raw, hashlib.sha256(raw).hexdigest())
        raw, texture_hash = cache[source_file]
        color = props.get('color', [1.0, 1.0, 1.0])
        identity = {'texture_sha256': texture_hash, 'mode': mode, 'linear_color': color,
                    'width': texture['width'], 'height': texture['height'], 'mipmaps': texture['godot_has_mipmaps']}
        key = hashlib.sha256(json.dumps(identity, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        target = output / (key + '.rgba16f')
        if not target.exists():
            chunks = []
            offset = 0
            width, height = int(texture['width']), int(texture['height'])
            while True:
                length = width * height * 4
                pixels = np.frombuffer(raw, dtype=np.uint8, count=length, offset=offset).reshape(-1, 4).astype(np.float32) / 255.0
                rgb = np.where(pixels[:, :3] <= .04045, pixels[:, :3] / 12.92, ((pixels[:, :3] + .055) / 1.055) ** 2.4)
                alpha = pixels[:, 3:4]
                base = np.asarray(color, dtype=np.float32)
                if mode == 1:
                    rgb = rgb + base * alpha
                else:
                    luminance = np.clip(rgb.sum(axis=1, keepdims=True) * .3333 / .19, .55, 1.35)
                    rgb = rgb * (1 - alpha * .96) + base * luminance * alpha * .96
                baked = np.concatenate((rgb, np.ones_like(alpha)), axis=1).astype('<f2')
                chunks.append(baked.tobytes())
                offset += length
                if not texture['godot_has_mipmaps'] or (width == 1 and height == 1):
                    break
                width, height = max(1, width // 2), max(1, height // 2)
            if offset != len(raw):
                raise ValueError('Unexpected mip payload size: ' + str(source_file))
            target.write_bytes(b''.join(chunks))
        entry = {'file': target.name, 'width': texture['width'], 'height': texture['height'],
                 'mipmaps': texture['godot_has_mipmaps'], 'mode': mode, 'identity': identity,
                 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}
        if material['id'] in manifest and manifest[material['id']] != entry:
            raise ValueError('Conflicting material ID: ' + material['id'])
        manifest[material['id']] = entry
(output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
print(f'Baked {len(set(item["file"] for item in manifest.values()))} textures for {len(manifest)} source materials.')
