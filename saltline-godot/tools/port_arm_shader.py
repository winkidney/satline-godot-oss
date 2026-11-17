#!/usr/bin/env python3
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
data=json.loads((root/'assets/prepared/scene.json').read_text())
m=next(m for m in data['materials'] if m['name']=='saltline_arm')
src=m['patch']['fragmentShader']
helpers=src[src.index('uniform float uArmWet;'):src.index('#include <packing>')]
body=src[src.index('  vec3 armPx ='):src.index('  diffuseColor.rgb = armCol;')]
shader='''shader_type spatial;
render_mode cull_disabled;
// Exact source armSurface, armMicro and armBump equations.
'''+helpers+'''
varying vec3 v_view_pos;
void vertex(){vArmRest=CUSTOM1;vArmHand=CUSTOM2;vArmN=CUSTOM0.xyz;v_view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
'''+body.replace('-vViewPosition','v_view_pos')+'''
 ALBEDO=armCol;ROUGHNESS=armRough;METALLIC=0.0;NORMAL=armBump(normalize(NORMAL),v_view_pos,armH);
}
'''
(root/'shaders/arms.gdshader').write_text(shader)
print({'arm_shader_lines':len(shader.splitlines())})

from sun_shader_bridge import inject_file
inject_file(root/"shaders"/"arms.gdshader")
