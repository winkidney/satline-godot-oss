shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec2 uScale;uniform float uFace;uniform vec2 uGradient;
varying vec2 original_uv;
#include "res://shaders/source_weapon_bump.gdshaderinc"
void vertex(){original_uv=VERTEX.xy*.5+.5;}
void fragment(){vec2 uv=original_uv;vec3 p=vec3((uv.x-.5)*2.*uScale.x,(uv.y-.5)*3.*uScale.y,uv.x*.3+uv.y*.2);vec3 n=normalize(vec3(.1,.2,1))*uFace;vec3 normal=sourceWeaponBump(n,p,dot(p.xy,uGradient));ALBEDO=normal*.5+.5;}
