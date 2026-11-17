shader_type spatial;
uniform sampler2D reflection_tex:source_color,filter_linear;
uniform mat4 reflected_view;
uniform mat4 reflected_projection;
uniform float wetness:hint_range(0.0,1.0)=0.8;
uniform bool planar=true;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float n=sin(p.x*61.0)*sin(p.y*47.0)*0.55+sin(p.x*12.0+p.y*7.0)*0.45;
 float wet=clamp(wetness+wetness*(1.0-wetness)*(sin(p.x*1.4)+sin(p.y*1.7))*0.56,0.0,1.0);
 ALBEDO=mix(vec3(0.18,0.2,0.21),vec3(0.07,0.085,0.095),wet)*(1.0+n*0.12);
 ROUGHNESS=mix(0.8,0.075,wet);
 vec2 gradient=vec2(0.55*61.0*cos(p.x*61.0)*sin(p.y*47.0)+0.45*12.0*cos(p.x*12.0+p.y*7.0),
 0.55*47.0*sin(p.x*61.0)*cos(p.y*47.0)+0.45*7.0*cos(p.x*12.0+p.y*7.0));
 vec3 world_normal=normalize(vec3(-gradient.x*0.0012*(1.0-wet),1.0,-gradient.y*0.0012*(1.0-wet)));
 NORMAL=normalize(mat3(VIEW_MATRIX)*world_normal);
 METALLIC=0.0;
 vec4 clip=reflected_projection*reflected_view*vec4(world,1.0);
 vec2 uv=clip.xy/clip.w*0.5+0.5;uv.y=1.0-uv.y;
 float inside=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0)*step(0.0,clip.w);
 float fresnel=0.04+0.96*pow(1.0-max(dot(NORMAL,VIEW),0.0),5.0);
 if(planar){vec3 refl=vec3(0.0);
 for(int y=-1;y<=1;y++){for(int x=-1;x<=1;x++){vec2 delta=vec2(float(x),float(y))*ROUGHNESS*ROUGHNESS*0.018;refl+=textureLod(reflection_tex,clamp(uv+delta,vec2(0.001),vec2(0.999)),0.0).rgb/9.0;}}
 EMISSION=refl*inside*wet*min(0.85,fresnel+0.23);}
}
