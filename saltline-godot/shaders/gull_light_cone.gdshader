shader_type spatial;
render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never,fog_disabled;
uniform vec3 uColor=vec3(1.0,.9,.74);
uniform float uGain=.085;
varying float taper;
varying vec3 view_normal;
varying vec3 to_camera;
void vertex(){
 view_normal=(MODELVIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
 to_camera=-(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
 taper=1.0-UV.y;
}
void fragment(){
 float facing=abs(dot(normalize(view_normal),normalize(to_camera)));
 facing=facing*facing*(3.0-2.0*facing);
 float t=clamp(taper,0.0,1.0);
 float falloff=pow(1.0-t,1.7)*(.35+.65*smoothstep(0.0,.06,t));
 ALBEDO=uColor*(uGain*facing*falloff);
 ALPHA=0.0;
}
