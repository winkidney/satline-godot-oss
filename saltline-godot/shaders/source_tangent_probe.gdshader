shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec2 uScale;uniform float uFace;uniform vec3 uMap;
#include "res://shaders/source_tangent_normal.gdshaderinc"
void fragment(){vec2 uv=vec2(UV.x,1.0-UV.y);vec3 p=vec3((uv.x-.5)*2.,(uv.y-.5)*3.,uv.x*.3+uv.y*.2);vec3 n=normalize(vec3(.1,.2,1))*uFace;vec3 normal=sourceTangentNormal(p,uv*uScale,n,uMap,uFace);COLOR=vec4(normal*.5+.5,1);}
