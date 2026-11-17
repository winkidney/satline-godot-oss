shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform vec2 uFootprint;uniform vec2 uPixel;uniform float uAlpha;
#include "res://shaders/source_alpha_cut.gdshaderinc"
void fragment(){COLOR=vec4(sourceDistanceAlpha(uAlpha,uFootprint,uPixel),0,1);}
