shader_type sky;
uniform sampler2D background_panorama:filter_linear,repeat_enable;
uniform sampler2D lighting_panorama:filter_linear,repeat_enable;
void sky(){
 vec3 d=normalize(EYEDIR);
 vec2 uv=vec2(fract(atan(d.x,d.z)/6.28318530718),acos(clamp(d.y,-1.0,1.0))/3.14159265359);
 COLOR=AT_CUBEMAP_PASS?texture(lighting_panorama,uv).rgb:texture(background_panorama,uv).rgb;
}
