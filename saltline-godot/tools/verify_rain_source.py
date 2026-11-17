#!/usr/bin/env python3
import json,re,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text());results=[]
normalize=lambda s:re.sub(r'\s+','',s)
for name,key in [('rain','uDrip'),('rain_splash','uMaskRect')]:
 record=next(m for m in scene['materials'] if m['type']=='ShaderMaterial' and key in m.get('uniforms',{}))
 native=(root/f'shaders/{name}.gdshader').read_text()
 source=record['fragmentShader'];fragment=source[source.index('void main(){'):].replace('void main(){','void fragment(){')
 fragment=re.sub(r'gl_FragColor = vec4\(vCol, (.*?)\);',r'ALBEDO=vCol;ALPHA=\1;',fragment)
 assert normalize(fragment) in normalize(native)
 assert 'vec4 aSeed=INSTANCE_CUSTOM' in native and 'blend_add' in native and 'depth_draw_never' in native
 results.append({'shader':name,'sha256':hashlib.sha256(native.encode()).hexdigest(),'fragment_match':True})
report={'failures':[],'results':results,'scope':'Original rain and crown-splash fragment equations preserved after output API rename; instance seed path/additive/depth modes checked. Full vertex physics validated separately by GPU probes; not final color parity.'}
(root/'evidence/rain-source-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
