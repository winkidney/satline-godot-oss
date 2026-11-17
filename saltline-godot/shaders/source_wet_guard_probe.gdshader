shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform uint uGuard=0u;
uniform vec3 uPos;uniform vec3 uNormal;uniform vec3 uFootprint;
uniform vec4 uMacro;uniform vec4 uParams;
uniform bool uTri;
uniform int uTint;
uniform float uRain;uniform float uIndoor;
float slRound(float x){return uintBitsToFloat(floatBitsToUint(x)+uGuard);}
vec3 slRound3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(uGuard));}
float slH(vec3 p){p=fract(slRound3(p*.3183099)+vec3(.71,.113,.419));p=slRound3(p*17.0);float xy=slRound(p.x*p.y);float xyz=slRound(xy*p.z);float sum=slRound(slRound(p.x+p.y)+p.z);return fract(slRound(xyz*sum));}
float slN3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.0-2.0*f);return mix(mix(mix(slH(i),slH(i+vec3(1,0,0)),f.x),mix(slH(i+vec3(0,1,0)),slH(i+vec3(1,1,0)),f.x),f.y),mix(mix(slH(i+vec3(0,0,1)),slH(i+vec3(1,0,1)),f.x),mix(slH(i+vec3(0,1,1)),slH(i+vec3(1,1,1)),f.x),f.y),f.z);}
#include "res://shaders/source_wet_surface.gdshaderinc"
void fragment(){vec4 texel=vec4(.24,.45,.61,.7);float a,b,w,up,bead;sourceWetSurface(uPos,uNormal,vec4(.3,.6,.8,1),uTri,uTint,uMacro,uParams,uRain,uIndoor,uFootprint,texel,a,b,w,up,bead);COLOR=vec4(w,up,bead,texel.r);}
