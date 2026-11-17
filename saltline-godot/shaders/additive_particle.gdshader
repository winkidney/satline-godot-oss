shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D atlas_tex:filter_linear_mipmap,repeat_disable;
uniform vec2 atlas_grid=vec2(4.0,2.0);
uniform float world_pixel_size=.002;
varying vec2 atlas_uv;
varying vec3 radiance;
varying float particle_alpha;
void vertex(){
 vec2 c=VERTEX.xy;
 vec4 pos=CUSTOM0;
 vec4 axis=CUSTOM1;
 vec4 col=CUSTOM2;
 vec4 misc=CUSTOM3;
 vec3 center=pos.xyz;
 float size=pos.w;
 vec3 cam_r=INV_VIEW_MATRIX[0].xyz;
 vec3 cam_u=INV_VIEW_MATRIX[1].xyz;
 vec3 to_camera=CAMERA_POSITION_WORLD-center;
 float distance=length(to_camera);
 to_camera/=max(distance,.0001);
 float sn=sin(axis.w),cs=cos(axis.w);
 vec2 rc=vec2(c.x*cs-c.y*sn,c.x*sn+c.y*cs);
 vec3 offset;
 float compensation=1.0;
 if(misc.y<.5){
  offset=(cam_r*rc.x+cam_u*rc.y)*size;
 }else if(misc.y<1.5){
  float axis_length=length(axis.xyz);
  vec3 direction=axis.xyz/max(axis_length,.00001);
  vec3 side=cross(direction,to_camera);
  float side_length=length(side);
  side=side_length>.001?side/side_length:cam_r;
  float width=max(size,distance*world_pixel_size*1.4);
  compensation=size/width;
  if(misc.w>1.5)width=min(width,distance*world_pixel_size*misc.w);
  offset=direction*(c.x*max(axis_length,width))+side*(c.y*width);
 }else{
  vec3 normal=normalize(axis.xyz);
  vec3 tangent=normalize(abs(normal.y)>.9?cross(normal,vec3(1.0,0.0,0.0)):cross(vec3(0.0,1.0,0.0),normal));
  vec3 bitangent=cross(normal,tangent);
  offset=(tangent*rc.x+bitangent*rc.y)*size;
 }
 VERTEX=center+offset;
 float frame=floor(misc.x+.5);
 atlas_uv=(vec2(mod(frame,atlas_grid.x),floor(frame/atlas_grid.x))+c+.5)/atlas_grid;
 radiance=col.rgb*compensation;
 particle_alpha=col.a;
}
void fragment(){
 float amount=texture(atlas_tex,vec2(atlas_uv.x,1.0-atlas_uv.y)).r*particle_alpha;
 if(amount<.002)discard;
 ALBEDO=radiance*amount;
 ALPHA=0.0;
}
