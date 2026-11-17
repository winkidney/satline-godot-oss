shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec3 uPos;uniform vec3 uNormal;uniform vec3 uFootprint;
uniform vec4 uMacro;uniform vec4 uParams;
uniform bool uTri;
uniform int uTint;
uniform float uRain;uniform float uIndoor;
float slH(vec3 p){p=fract(p*.3183099+vec3(.71,.113,.419));p*=17.0;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float slN3(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.0-2.0*f);return mix(mix(mix(slH(i),slH(i+vec3(1,0,0)),f.x),mix(slH(i+vec3(0,1,0)),slH(i+vec3(1,1,0)),f.x),f.y),mix(mix(slH(i+vec3(0,0,1)),slH(i+vec3(1,0,1)),f.x),mix(slH(i+vec3(0,1,1)),slH(i+vec3(1,1,1)),f.x),f.y),f.z);}
#include "res://shaders/source_wet_surface.gdshaderinc"
uniform vec4 uState;
void fragment(){vec4 params=vec4(.3,.4,.6,.9),macro=vec4(.2,.15,1.7,.4);vec3 color=sourceWetColor(vec3(.21,.48,.87),uState.z,params);float r=clamp(sourceWetRoughness(.8,.6,macro,params,uState.x,uState.y,uState.z,uState.w),.045,1.0);COLOR=vec4(color,r);}
