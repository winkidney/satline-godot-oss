#!/usr/bin/env python3
import json,re,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
record=next(m for m in json.loads((root/'assets/prepared/scene.json').read_text())['materials'] if m['name']=='sea')
v=record['patch']['vertexShader'];vertex=v[v.index('  vec3 swp ='):v.index('  vGWorld = swp;')+len('  vGWorld = swp;')].replace('modelMatrix','MODEL_MATRIX').replace('transformed','VERTEX')
f=record['patch']['fragmentShader'];start=f.index('{\n  vec2 sxz =');surface=f[start:f.index('\n}\n',start)+2].replace('cameraPosition','sea_camera').replace('texture2D(','sourceSample(')
native=(root/'shaders/sea.gdshader').read_text();normalize=lambda s:re.sub(r'\s+','',s)
assert normalize(vertex) in normalize(native)
assert normalize(surface) in normalize(native)
assert 'vec2(uv.x,1.0-uv.y)' in native
report={'failures':[],'material':record['id'],'shader_sha256':hashlib.sha256(native.encode()).hexdigest(),'scope':'Original exported vertex displacement and full surface block unchanged except Godot API/sampler rename. Lighting bridge, IBL occlusion and haze integration are separate from source parity.'}
(root/'evidence/sea-source-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
