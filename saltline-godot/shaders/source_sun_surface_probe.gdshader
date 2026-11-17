shader_type spatial;
render_mode cull_disabled,specular_occlusion_disabled;
#include "res://shaders/source_sun_brdf.gdshaderinc"
#include "res://shaders/source_sun_pcss.gdshaderinc"
uniform sampler2D source_shadow:filter_nearest,repeat_disable;
uniform mat4 source_shadow_matrix;
uniform vec2 source_shadow_size=vec2(4096.0);
uniform vec3 source_sun_direction=vec3(.9163473614874841,.22508532350948027,.33112552036283543);
uniform bool source_receive_shadow=true;
uniform vec3 source_base=vec3(.45,.21,.07);
uniform float source_metal=0.0;
uniform float source_roughness=.6;
varying vec4 source_shadow_coord;
void vertex(){vec3 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;vec3 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);source_shadow_coord=source_shadow_matrix*vec4(world_pos+world_normal*.02,1.0);}
void fragment(){vec3 normal=normalize(NORMAL);vec3 dxy=max(abs(dFdx(normal)),abs(dFdy(normal)));float geometry_roughness=max(max(dxy.x,dxy.y),dxy.z);PhysicalMaterial material;material.diffuseColor=source_base*(1.0-source_metal);material.roughness=min(max(source_roughness,.0525)+geometry_roughness,1.0);material.specularColor=mix(vec3(.04),source_base,source_metal);material.specularF90=1.0;float visibility=1.0;if(source_receive_shadow)visibility=getShadow(source_shadow,source_shadow_size,1.0,-.00012,1.0,source_shadow_coord,vec2(FRAGCOORD.x,VIEWPORT_SIZE.y-FRAGCOORD.y));IncidentLight light;light.direction=normalize((VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz);light.color=vec3(1.0,.72,.42)*9.0*visibility;light.visible=true;ReflectedLight reflected;reflected.directDiffuse=vec3(0.0);reflected.directSpecular=vec3(0.0);reflected.indirectDiffuse=vec3(0.0);reflected.indirectSpecular=vec3(0.0);RE_Direct_Physical(light,VERTEX,normal,normalize(-VERTEX),normal,material,reflected);ALBEDO=vec3(0.0);ROUGHNESS=.6;METALLIC=0.0;EMISSION=reflected.directDiffuse+reflected.directSpecular;}
