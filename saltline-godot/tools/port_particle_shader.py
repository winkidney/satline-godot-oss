#!/usr/bin/env python3
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
source=next(m for m in scene['materials'] if m['name']=='fx_lit')['fragmentShader']
shader=(root/'shaders/additive_particle.gdshader').read_text().split('void fragment(){')[0]
shader=shader.replace('varying vec2 atlas_uv;','''varying vec2 atlas_uv;
varying vec3 vOff;
varying vec3 vToCam;
varying vec3 vInfo;
varying float vSoftD;
varying vec3 vT;
varying vec3 vB;
uniform vec3 uSun;
uniform vec3 uSunDir;
uniform vec3 uAmbLo;
uniform vec3 uAmbHi;
uniform sampler2D depth_tex:hint_depth_texture,filter_nearest,repeat_disable;
uniform bool soft_particles=true;''')
shader=shader.replace('offset=(cam_r*rc.x+cam_u*rc.y)*size;','offset=(cam_r*rc.x+cam_u*rc.y)*size;vT=cam_r*cs+cam_u*sn;vB=cam_u*cs-cam_r*sn;')
shader=shader.replace('offset=direction*(c.x*max(axis_length,width))+side*(c.y*width);','offset=direction*(c.x*max(axis_length,width))+side*(c.y*width);vT=direction;vB=side;')
shader=shader.replace('offset=(tangent*rc.x+bitangent*rc.y)*size;','offset=(tangent*rc.x+bitangent*rc.y)*size;vT=tangent*cs+bitangent*sn;vB=bitangent*cs-tangent*sn;')
shader=shader.replace('VERTEX=center+offset;','''VERTEX=center+offset;
 vOff=offset/max(size,.0001);vToCam=to_camera;
 vInfo=vec3((VIEW_MATRIX*vec4(center+offset,1.0)).z,misc.z,misc.w);
 vSoftD=clamp(size*.4,.04,.7);''')
body=source[source.index('void main() {')+len('void main() {'):]
body=body[:body.rfind('}')]
body=body.replace('texture2D(uTex, vUv)','texture(atlas_tex,vec2(atlas_uv.x,1.0-atlas_uv.y))').replace('vCol.a','particle_alpha').replace('vCol.rgb','radiance')
body=re.sub(r'#include <[^>]+>','',body)
body=body.replace('softFade()', 'softFade(SCREEN_UV,INV_PROJECTION_MATRIX)')
body=body.replace('gl_FragColor = vec4(col, a);','ALBEDO=col*a;ALPHA=a;')
body=body.replace('gl_FragColor.rgb *= gl_FragColor.a;','')
soft='''float softFade(vec2 screen_uv,mat4 inverse_projection){
 if(!soft_particles)return 1.0;
 float depth=texture(depth_tex,screen_uv).r;
 vec4 position=inverse_projection*vec4(screen_uv*2.0-1.0,depth,1.0);
 float scene_z=position.z/position.w;
 return clamp((vInfo.x-scene_z)/vSoftD,0.0,1.0);
}
'''
(root/'shaders/lit_particle.gdshader').write_text(shader+soft+'void fragment(){\n'+body+'\n}\n')
print('Ported source billow lighting, erosion, forward scatter and fire lobe shading')
