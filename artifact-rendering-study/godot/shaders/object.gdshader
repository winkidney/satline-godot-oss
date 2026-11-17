shader_type spatial;
uniform vec4 color:source_color=vec4(0.8,0.2,0.05,1.0);
uniform float emission=0.0;
varying float world_y;
void vertex(){world_y=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}
void fragment(){if(CAMERA_POSITION_WORLD.y<0.0&&world_y<0.0){discard;} ALBEDO=color.rgb;ROUGHNESS=0.32;METALLIC=0.15;EMISSION=color.rgb*emission;}
