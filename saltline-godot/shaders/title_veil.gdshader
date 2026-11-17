shader_type canvas_item;
render_mode unshaded;
void fragment(){
 float horizontal=UV.x<.38?mix(209./255.,128./255.,UV.x/.38):UV.x<.72?mix(128./255.,0.,(UV.x-.38)/.34):0.;
 float vertical=(179./255.)*(1.-clamp((1.-UV.y)/.46,0.,1.));
 float alpha=horizontal+vertical*(1.-horizontal);
 COLOR*=vec4(vec3(6.,8.,10.)/255.,alpha);
}
