shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec3 uPos;uniform vec3 uNormal;uniform vec3 uFootprint;
uniform vec4 uMacro;uniform vec4 uParams;
uniform bool uTri;
uniform int uTint;
uniform float uRain;uniform float uIndoor;
#include "res://shaders/source_material_noise.gdshaderinc"
#include "res://shaders/source_wet_surface.gdshaderinc"
void fragment(){vec4 texel=vec4(.24,.45,.61,.7);float a,b,w,up,bead;sourceWetSurface(uPos,uNormal,vec4(.3,.6,.8,1),uTri,uTint,uMacro,uParams,uRain,uIndoor,uFootprint,texel,a,b,w,up,bead);COLOR=vec4(w,up,bead,texel.r);}
