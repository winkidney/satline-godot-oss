shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec3 uPos;uniform vec3 uNormal;uniform vec3 uFootprint;
uniform vec4 uMacro;uniform vec4 uParams;
uniform bool uTri;
uniform int uTint;
uniform float uRain;uniform float uIndoor;
#include "res://shaders/source_material_noise.gdshaderinc"
#include "res://shaders/source_wet_surface.gdshaderinc"
uniform vec4 uState;
#include "res://shaders/source_material_color.gdshaderinc"
uniform vec4 uTexel;uniform vec4 uVertex;uniform float uWet;
void fragment(){vec3 color=sourceMaterialColor(vec3(.3,.5,.7),uTexel,uTint);color=sourceWetColor(color,uWet,vec4(.3,.4,.6,.9));COLOR=vec4(color*uVertex.rgb,.8*(uTint==3?uTexel.a:1.0)*uVertex.a);}
