#!/usr/bin/env python3
"""Preserve exported original sea wave/surface equations; bridge lighting to Godot."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
record=next(m for m in json.loads((root/'assets/prepared/scene.json').read_text())['materials'] if m['name']=='sea')
v=record['patch']['vertexShader'];vertex=v[v.index('  vec3 swp ='):v.index('  vGWorld = swp;')+len('  vGWorld = swp;')]
vertex=vertex.replace('modelMatrix','MODEL_MATRIX').replace('transformed','VERTEX')
f=record['patch']['fragmentShader'];start=f.index('{\n  vec2 sxz =');surface=f[start:f.index('\n}\n',start)+2]
surface=surface.replace('cameraPosition','sea_camera').replace('texture2D(','sourceSample(')
header="""shader_type spatial;
render_mode diffuse_lambert,specular_schlick_ggx;
uniform float uTime=0.0;
uniform sampler2D uDetail:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetailN:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec3 uHazeA=vec3(.136,.187,.255);
uniform vec3 uHazeB=vec3(.76,.44,.224);
uniform vec3 uSunDirW=vec3(.9163473615,.2250853235,.3311255204);
varying vec3 vGWorld;
varying float vSAmp;
varying vec3 sea_camera;
varying float sea_glitter;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}
void vertex(){
 sea_camera=INV_VIEW_MATRIX[3].xyz;
"""
bridge="""
 ALBEDO=diffuseColor.rgb;ROUGHNESS=gRough;METALLIC=0.0;SPECULAR=.5;
 NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(vec3(-gNxz.x,1.0,-gNxz.y)));
 AO=clamp(gOcc,0.0,1.0);AO_LIGHT_AFFECT=0.0;
 vec3 sdir=normalize(vGWorld-sea_camera);
 float az=max(dot(normalize(sdir.xz+vec2(1e-5)),normalize(uSunDirW.xz)),0.0);
 sea_glitter=gSpark*mix(.3,1.0,az*az*az);
 FOG=vec4(mix(uHazeA,uHazeB,pow(az,3.0)),smoothstep(220.0,860.0,gSDist)*.8);
}
void light(){
 float nl=max(dot(NORMAL,LIGHT),0.0),nv=max(dot(NORMAL,VIEW),1e-5);
 vec3 half_vector=normalize(LIGHT+VIEW);
 float nh=max(dot(NORMAL,half_vector),0.0),vh=max(dot(VIEW,half_vector),0.0);
 float a=ROUGHNESS*ROUGHNESS,a2=a*a;
 float den=nh*nh*(a2-1.0)+1.0;
 float distribution=a2/(3.14159265359*den*den);
 float visibility=.5/max(nl*sqrt(a2+(1.0-a2)*nv*nv)+nv*sqrt(a2+(1.0-a2)*nl*nl),1e-6);
 vec3 fresnel=vec3(.04)+vec3(.96)*exp2((-5.55473*vh-6.98316)*vh);
 DIFFUSE_LIGHT+=LIGHT_COLOR*ATTENUATION*nl/3.14159265359;
 vec3 direct_specular=LIGHT_COLOR*ATTENUATION*nl*distribution*visibility*fresnel;
 SPECULAR_LIGHT+=min(direct_specular,vec3(40.0))*sea_glitter;
}
"""
(root/'shaders/sea.gdshader').write_text(header+vertex+'\n}\nvoid fragment(){\n float gRough,gOcc,gSDist,gSpark;vec2 gNxz;vec4 diffuseColor=vec4(1.0);\n'+surface+'\n'+bridge)
print('Ported original sea equations',record['id'])

from sun_shader_bridge import inject_file
inject_file(root/"shaders"/"sea.gdshader")
