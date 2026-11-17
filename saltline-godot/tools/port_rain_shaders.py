#!/usr/bin/env python3
"""Port original rain/eave-drip and splash shaders without reseeding their instances."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
for name,key in [('rain','uDrip'),('rain_splash','uMaskRect')]:
 record=next(m for m in scene['materials'] if m['type']=='ShaderMaterial' and key in m.get('uniforms',{}))
 vertex=record['vertexShader'];fragment=record['fragmentShader']
 vertex=vertex.replace('attribute vec4 aSeed;','')
 vertex=re.sub(r'uniform (float|vec3) ([^;]+);',lambda m:' '.join('uniform '+m[1]+' '+v.strip()+';' for v in m[2].split(',')),vertex)
 vertex=vertex.replace('void main(){','void vertex(){\n vec4 aSeed=INSTANCE_CUSTOM;vec3 rain_camera=INV_VIEW_MATRIX[3].xyz;')
 vertex=vertex.replace('position.xy','VERTEX.xy').replace('position.y','VERTEX.y').replace('position.x','VERTEX.x')
 vertex=vertex.replace('cameraPosition','rain_camera').replace('projectionMatrix','PROJECTION_MATRIX').replace('viewMatrix','VIEW_MATRIX').replace('gl_Position','POSITION')
 vertex=vertex.replace('uniform sampler2D uMask;','uniform sampler2D uMask:filter_linear,repeat_disable;')
 vertex=vertex.replace('textureLod(uMask, muv, 0.0)','textureLod(uMask, vec2(muv.x,1.0-muv.y), 0.0)')
 fragment=fragment[fragment.index('void main(){'):].replace('void main(){','void fragment(){')
 fragment=re.sub(r'gl_FragColor = vec4\(vCol, (.*?)\);',r'ALBEDO=vCol;ALPHA=\1;',fragment)
 header='shader_type spatial;\nrender_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;\n'
 (root/f'shaders/{name}.gdshader').write_text(header+vertex+'\n'+fragment+'\n')
 print('Ported',name,record['id'])
