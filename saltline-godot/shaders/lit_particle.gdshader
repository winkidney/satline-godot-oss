shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform sampler2D atlas_tex:filter_linear_mipmap,repeat_disable;
uniform vec2 atlas_grid=vec2(4.0,2.0);
uniform float world_pixel_size=.002;
varying vec2 atlas_uv;
varying vec3 vOff;
varying vec3 vToCam;
varying vec3 vInfo;
varying float vSoftD;
varying vec3 vT;
varying vec3 vB;
uniform vec3 uSun;
uniform vec3 uSunDir;
uniform vec3 uAmbLo;
uniform vec3 uAmbHi;
uniform sampler2D depth_tex:hint_depth_texture,filter_nearest,repeat_disable;
uniform bool soft_particles=true;
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
  offset=(cam_r*rc.x+cam_u*rc.y)*size;vT=cam_r*cs+cam_u*sn;vB=cam_u*cs-cam_r*sn;
 }else if(misc.y<1.5){
  float axis_length=length(axis.xyz);
  vec3 direction=axis.xyz/max(axis_length,.00001);
  vec3 side=cross(direction,to_camera);
  float side_length=length(side);
  side=side_length>.001?side/side_length:cam_r;
  float width=max(size,distance*world_pixel_size*1.4);
  compensation=size/width;
  if(misc.w>1.5)width=min(width,distance*world_pixel_size*misc.w);
  offset=direction*(c.x*max(axis_length,width))+side*(c.y*width);vT=direction;vB=side;
 }else{
  vec3 normal=normalize(axis.xyz);
  vec3 tangent=normalize(abs(normal.y)>.9?cross(normal,vec3(1.0,0.0,0.0)):cross(vec3(0.0,1.0,0.0),normal));
  vec3 bitangent=cross(normal,tangent);
  offset=(tangent*rc.x+bitangent*rc.y)*size;vT=tangent*cs+bitangent*sn;vB=bitangent*cs-tangent*sn;
 }
 VERTEX=center+offset;
 vOff=offset/max(size,.0001);vToCam=to_camera;
 vInfo=vec3((VIEW_MATRIX*vec4(center+offset,1.0)).z,misc.z,misc.w);
 vSoftD=clamp(size*.4,.04,.7);
 float frame=floor(misc.x+.5);
 atlas_uv=(vec2(mod(frame,atlas_grid.x),floor(frame/atlas_grid.x))+c+.5)/atlas_grid;
 radiance=col.rgb*compensation;
 particle_alpha=col.a;
}
float softFade(vec2 screen_uv,mat4 inverse_projection){
 if(!soft_particles)return 1.0;
 float depth=texture(depth_tex,screen_uv).r;
 vec4 position=inverse_projection*vec4(screen_uv*2.0-1.0,depth,1.0);
 float scene_z=position.z/position.w;
 return clamp((vInfo.x-scene_z)/vSoftD,0.0,1.0);
}
void fragment(){

  vec4 t = texture(atlas_tex,vec2(atlas_uv.x,1.0-atlas_uv.y));
  float er = vInfo.y * 0.45;                                  // wisps erode as the puff ages
  float a = smoothstep(er, er + (vInfo.z > 1.5 ? 0.38 : 0.6), t.a) * particle_alpha;   // fire lobes: denser body, crisper edge
  a *= softFade(SCREEN_UV,INV_PROJECTION_MATRIX) * smoothstep(0.2, 0.9, -vInfo.x);           // soft intersection + fade right at the lens
  if (a < 0.004) discard;
  vec3 V = normalize(vToCam);
  vec3 q = vOff * 2.0; float r2 = min(dot(q, q), 1.0);
  vec3 Ns = q + V * (sqrt(1.0 - r2) * 0.9 + 0.05);            // overall sphere normal
  vec2 tn = t.rg * 2.0 - 1.0;                                 // billow normal from the flipbook
  vec3 Nb = vT * tn.x + vB * tn.y + V * sqrt(max(1.0 - dot(tn, tn), 0.0));
  vec3 N = normalize(Ns * 0.55 + Nb);
  float wrap = clamp((dot(N, uSunDir) + 0.45) / 1.45, 0.0, 1.0);
  float back = pow(clamp(dot(-V, uSunDir), 0.0, 1.0), 5.0);   // looking into the sun: forward scatter through thin edges
  float thin = 1.0 - t.b * smoothstep(0.0, 0.5, a);
  float hot = step(1.5, vInfo.z), shade = vInfo.z - 2.0 * hot;      // aMisc.w >= 2: emissive fire lobe (colour = emission)
  vec3 sun = uSun * (wrap * wrap * 0.85 + back * (0.15 + 1.3 * thin)) * shade;
  vec3 amb = mix(uAmbLo, uAmbHi, N.y * 0.5 + 0.5) * (1.0 - 0.35 * t.b);
  vec3 col = radiance * (amb + sun);
  if (hot > 0.5) {
    // alpha-blended fire: hot dense cores, dim orange skin, soot underneath. Because it is NOT additive, overlapping lobes
    // keep their shape and smoke in front can occlude them.
    float lump = clamp(dot(tn, vec2(0.6, 0.8)) * 0.6 + 0.5, 0.0, 1.0);
    float core = t.b * t.b * smoothstep(0.15, 0.9, t.a);
    vec3 fire = radiance * (0.10 + 1.7 * core) * (0.45 + 1.1 * lump);
    col = vec3(0.045, 0.042, 0.04) * (amb + sun) + fire;
  }
  ALBEDO=col*a;ALPHA=a;
  
  
                           // premultiply after the (possibly no-op) output transform

}
