shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D source_tex:source_color,filter_linear_mipmap,repeat_enable;
uniform float lod=0.0;
void fragment(){COLOR=textureLod(source_tex,vec2(.125),lod);}
