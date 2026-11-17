#!/usr/bin/env python3
"""Translate the actual source apron material equations, retaining sampling semantics."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
scene=json.loads((root/'assets/prepared/scene.json').read_text())
material=next(m for m in scene['materials'] if m['name']=='apron_wet')
fragment=material['patch']['fragmentShader']
common=fragment.split('#include <common>',1)[1].split('#include <packing>',1)[0]
# ShaderLib puts packing after common; confirm we extracted the source helper block.
assert 'vec2 gRipple' in common
body=re.search(r'\{\n  vec2 gxz = vGWorld.xz;[\s\S]+?gRough = rough; gNxz = nxz; gPuddle = puddle; gWet = wet; gFilm = film;\n\}',fragment).group()
common=re.sub(r'float gRough; vec2 gNxz; float gPuddle; float gWet; float gFilm; float gSoak;','',common)
common=re.sub(r'uniform (float|vec[234]|mat4) ([A-Za-z0-9_, ]+);',lambda m:'\n'.join('uniform '+m[1]+' '+n.strip()+';' for n in m[2].split(',')),common)
common=common.replace('varying vec3 vGWorld;','varying vec3 vGWorld;')
common=common.replace('uniform sampler2D uMask, uMarks, uDetail, uDetailN, uRefl;', '''uniform sampler2D uMask:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uMarks:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetail:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetailN:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uRefl:filter_linear_mipmap_anisotropic,repeat_enable;''')
helpers='''
vec4 sourceSample(sampler2D t,vec2 uv){return texture(t,vec2(uv.x,1.0-uv.y));}
vec4 sourceLod(sampler2D t,vec2 uv,float lod){vec2 edge=0.5/vec2(textureSize(t,0));uv=clamp(uv,edge,vec2(1.0)-edge);return textureLod(t,vec2(uv.x,1.0-uv.y),lod);}
'''
common=common.replace('textureLod(', 'sourceLod(').replace('texture2D(', 'sourceSample(')
body=body.replace('texture2D(', 'sourceSample(').replace('cameraPosition','CAMERA_POSITION_WORLD').replace('sourceSample(uMarks, kuv)','sourceSample(uMarks, clamp(kuv, vec2(0.5/uMarkRes), vec2(1.0-0.5/uMarkRes)))')
shader='''shader_type spatial;
render_mode cull_disabled;
// Source apron equations. Planar radiance replacement is integrated separately.
'''+helpers+common+'''
void vertex(){vGWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float gRough=1.0;vec2 gNxz=vec2(0.0);float gPuddle=0.0,gWet=0.0,gFilm=0.0,gSoak=0.0;
 vec4 diffuseColor=vec4(1.0);
'''+body+'''
 ALBEDO=diffuseColor.rgb;ROUGHNESS=gRough;METALLIC=0.0;
 NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(vec3(-gNxz.x,1.0,-gNxz.y)));
 SPECULAR=mix(.5,.9375,max(gPuddle,gSoak*.5));
}
'''
(root/'shaders/ground.gdshader').write_text(shader)
print({'ground_shader_lines':len(shader.splitlines()),'source_material':material['id']})

from sun_shader_bridge import inject_file
inject_file(root/"shaders"/"ground.gdshader")

from port_ground_reflection import inject_file as inject_reflection
inject_reflection(root/"shaders"/"ground.gdshader")
