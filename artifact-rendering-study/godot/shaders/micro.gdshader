shader_type spatial;
render_mode cull_disabled;
uniform bool filtering=true;
uniform float pitch_mm:hint_range(0.3,4.0)=1.2;
uniform float detail_strength:hint_range(0.0,1.0)=0.6;
varying vec3 rest;
void vertex(){rest=VERTEX;}
void fragment(){
 float pitch=pitch_mm*0.001;
 vec2 p=rest.xy;
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float fade=filtering?1.0-smoothstep(pitch*0.3,pitch*0.85,footprint):1.0;
 vec2 wave=sin(p*6.2831853/pitch);
 vec2 slope=cos(p*6.2831853/pitch)*vec2(wave.y,wave.x)*detail_strength;
 vec3 n=normalize(vec3(slope*fade,1.0));
 NORMAL_MAP=n*0.5+0.5;
 float variance=(1.0-fade)*detail_strength*detail_strength*0.22;
 ROUGHNESS=sqrt(0.22*0.22+variance);
 ALBEDO=vec3(0.23,0.39,0.47)*(0.9+0.1*wave.x*wave.y*fade);
 METALLIC=0.0;
}
