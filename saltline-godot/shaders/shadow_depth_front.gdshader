shader_type spatial;
render_mode unshaded,cull_back,depth_draw_opaque;
uniform vec2 shadow_projection_scale=vec2(1.0);
uniform sampler2D alpha_tex:filter_linear_mipmap,repeat_enable;
uniform sampler2D alpha_map:filter_linear_mipmap,repeat_enable;
uniform bool has_map=false;
uniform bool has_alpha_map=false;
uniform float opacity_value=1.0;
uniform float alpha_cut=0.0;
uniform vec2 uv_repeat=vec2(1.0);
uniform vec2 uv_offset=vec2(0.0);
void vertex(){PROJECTION_MATRIX[0][0]*=shadow_projection_scale.x;PROJECTION_MATRIX[1][1]*=shadow_projection_scale.y;}
void fragment(){
 if(alpha_cut>0.0){
  vec2 uv=UV*uv_repeat+uv_offset;uv.y=1.0-uv.y;
  float alpha=opacity_value;
  if(has_map)alpha*=texture(alpha_tex,uv).a;
  if(has_alpha_map)alpha*=texture(alpha_map,uv).g;
  if(alpha<alpha_cut)discard;
 }
 ALBEDO=vec3(0.0);
}
