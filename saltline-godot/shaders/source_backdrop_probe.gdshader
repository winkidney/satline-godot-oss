shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://shaders/source_backdrop.gdshaderinc"
uniform vec3 uPosition;uniform vec4 uOrbit;uniform vec4 uParameters;uniform vec3 uBlink;uniform float uTime;
void fragment(){vec4 result=vec4(sourceBackdropGull(uPosition,uOrbit,uParameters,uTime),sourceBackdropBlink(uBlink,uTime));int pixel=int(FRAGCOORD.x);uint bits=floatBitsToUint(result[pixel/2]);if(pixel%2==0)COLOR=vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),1);else COLOR=vec4(float((bits>>24u)&255u),0,0,1);}
