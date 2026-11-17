#!/usr/bin/env python3
"""Port the original ME sight shader, keeping its analytic glass and collimated reticle."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
record=next(m for m in json.loads((root/'assets/prepared/scene.json').read_text())['materials'] if 'uBright' in m.get('uniforms',{}))
source=record['fragmentShader']
body=source[source.index('void main(){')+len('void main(){'):source.rindex('}')]
body=body.replace('cameraPosition','sight_camera').replace('gl_FragColor = vec4(col, alpha);','ALBEDO=col;ALPHA=alpha;')
body='\n'.join(line for line in body.splitlines() if '#include' not in line)
header='shader_type spatial;\nrender_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;\nuniform float uBright=7.0;\nuniform vec3 uSun=vec3(.9163473615,.2250853235,.3311255204);\nuniform vec3 uSunCol=vec3(1.0,.72,.42);\nuniform vec3 uZen=vec3(.055,.085,.13);\nuniform vec3 uHor=vec3(.16,.22,.3);\nuniform float uTilt=.1;\nuniform float uEnv=1.0;\nvarying vec3 vView;\nvarying vec3 vFwd;\nvarying vec3 vRight;\nvarying vec3 vUp;\nvarying vec3 vWPos;\nvarying vec3 vWN;\nvarying vec2 vUv;\nvarying vec3 sight_camera;\nvoid vertex(){\n vUv=UV;\n vView=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;\n vFwd=(MODELVIEW_MATRIX*vec4(0.0,0.0,-1.0,0.0)).xyz;\n vRight=(MODELVIEW_MATRIX*vec4(1.0,0.0,0.0,0.0)).xyz;\n vUp=(MODELVIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;\n vWPos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;\n vWN=normalize(mat3(MODEL_MATRIX)*normalize(vec3(0.0,-uTilt,1.0)));\n sight_camera=INV_VIEW_MATRIX[3].xyz;\n}\nvoid fragment(){'
(root/'shaders/sight_glass.gdshader').write_text(header+'\n'+body+'\n}\n')
print('Ported original sight material',record['id'])
