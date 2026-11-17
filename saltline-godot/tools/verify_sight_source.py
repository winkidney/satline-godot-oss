#!/usr/bin/env python3
import hashlib,json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
record=next(m for m in json.loads((root/'assets/prepared/scene.json').read_text())['materials'] if 'uBright' in m.get('uniforms',{}))
s=record['fragmentShader'];expected=s[s.index('void main(){')+len('void main(){'):s.rindex('}')]
expected=expected.replace('cameraPosition','sight_camera').replace('gl_FragColor = vec4(col, alpha);','ALBEDO=col;ALPHA=alpha;')
expected='\n'.join(line for line in expected.splitlines() if '#include' not in line)
native=(root/'shaders/sight_glass.gdshader').read_text();actual=native[native.index('void fragment(){')+len('void fragment(){'):native.rindex('}')]
assert re.sub(r'\s+','',expected)==re.sub(r'\s+','',actual)
assert 'unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled' in native
assert 'ALBEDO=col;ALPHA=alpha;' in native
report={'failures':[],'material':record['id'],'shader_sha256':hashlib.sha256(native.encode()).hexdigest(),'scope':'Original exported fragment equations match verbatim after camera/output API rename and removal of source tone/color includes; Godot supplies its current post pipeline. Does not assert cross-engine tone mapping or pixel parity.'}
(root/'evidence/sight-source-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
