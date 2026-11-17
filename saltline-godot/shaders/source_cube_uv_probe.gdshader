shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D uEnv:filter_linear,repeat_disable;
uniform vec3 uDirection;uniform float uRoughness;
#include "res://shaders/source_cube_uv.gdshaderinc"
void fragment(){COLOR=sourceCubeTexture(uEnv,uDirection,uRoughness);}
