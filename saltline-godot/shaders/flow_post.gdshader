shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float fade=0.0;
uniform float saturation=1.0;
void fragment(){vec3 c=texture(screen_texture,SCREEN_UV).rgb;float l=dot(c,vec3(.2126,.7152,.0722));COLOR=vec4(mix(vec3(l),c,saturation)*(1.0-clamp(fade,0.0,1.0)),1.0);}
