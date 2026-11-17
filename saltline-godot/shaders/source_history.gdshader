shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D tHistory:filter_nearest,repeat_disable;
uniform bool uSeed=false;
void fragment(){COLOR=uSeed?vec4(0.0,0.0,0.0,1.0):texelFetch(tHistory,ivec2(0),0);}
