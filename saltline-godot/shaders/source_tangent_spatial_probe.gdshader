shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec2 uScale;uniform float uFace;uniform vec3 uMap;
varying vec2 original_uv;
#include "res://shaders/source_tangent_normal.gdshaderinc"
void vertex(){original_uv=VERTEX.xy*.5+.5;}
void fragment(){vec2 uv=original_uv;vec3 p=vec3((uv.x-.5)*2.,(uv.y-.5)*3.,uv.x*.3+uv.y*.2);vec3 n=normalize(vec3(.1,.2,1))*uFace;vec3 normal=sourceTangentNormal(p,uv*uScale,n,uMap,uFace);ALBEDO=normal*.5+.5;}
