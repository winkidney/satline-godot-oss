// Included after source_sun_surface: reuse original PhysicalMaterial/BRDF.
#include "res://shaders/source_local_light_math.gdshaderinc"
uniform sampler2D source_local_lights:filter_nearest,repeat_disable;
uniform bool source_local_ready=false;
uniform bool source_local_radiance_enabled=true;
instance uniform bool source_local_active:instance_index(11)=false;
int sourceLocalCameraMask(uint visible_layers){int mask=int(visible_layers&3u);if((visible_layers&4u)!=0u)mask|=1;return mask;}
bool sourceLocalVisible(int row,int camera_mask){vec4 state=texelFetch(source_local_lights,ivec2(3,row),0);return state.g>0.5&&((int(state.r)&camera_mask)!=0);}
void sourceLocalPoint(int row,vec3 geometry_position,mat4 view_matrix,out IncidentLight light){
 vec4 position_range=texelFetch(source_local_lights,ivec2(0,row),0);vec4 radiance_decay=texelFetch(source_local_lights,ivec2(1,row),0);
 SourcePointLight point;point.position=(view_matrix*vec4(position_range.xyz,1.0)).xyz;point.color=radiance_decay.rgb;point.distance=position_range.a;point.decay=radiance_decay.a;
 sourcePointLightInfo(point,geometry_position,light);
}
void sourceDirectTerms(vec3 base,float metal,float rough,float wet_f0,vec3 normal,vec3 unperturbed,vec3 view,vec3 light_direction,vec2 source_fragcoord,vec3 geometry_position,mat4 view_matrix,int camera_mask,out vec3 diffuse,out vec3 specular){
 vec3 dxy=max(abs(dFdx(unperturbed)),abs(dFdy(unperturbed)));float geometry_roughness=max(max(dxy.x,dxy.y),dxy.z);
 PhysicalMaterial material;material.diffuseColor=base*(1.0-metal);material.roughness=min(max(rough,.0525)+geometry_roughness,1.0);material.specularColor=mix(mix(vec3(.04),base,metal),vec3(.075),wet_f0);material.specularF90=1.0;
 ReflectedLight reflected;reflected.directDiffuse=vec3(0.0);reflected.directSpecular=vec3(0.0);reflected.indirectDiffuse=vec3(0.0);reflected.indirectSpecular=vec3(0.0);
 bool local=source_local_active&&source_local_ready&&source_local_radiance_enabled;
 if(local){for(int row=0;row<10;row++){if(sourceLocalVisible(row,camera_mask)){IncidentLight light;sourceLocalPoint(row,geometry_position,view_matrix,light);if(light.visible)RE_Direct_Physical(light,vec3(0.0),normal,view,normal,material,reflected);}}}
 if(source_sun_active&&source_sun_ready){
  float visibility=1.0;if(source_sun_receive_shadow)visibility=getShadow(source_sun_shadow,source_sun_shadow_size,1.0,-.00012,1.0,source_sun_shadow_coord,source_fragcoord);
  IncidentLight sun;sun.direction=normalize(light_direction);sun.color=vec3(1.0,.72,.42)*9.0*visibility;sun.visible=true;RE_Direct_Physical(sun,vec3(0.0),normal,view,normal,material,reflected);
 }
 if(local&&sourceLocalVisible(10,camera_mask)){
  IncidentLight key;key.direction=normalize((view_matrix*vec4(texelFetch(source_local_lights,ivec2(2,10),0).xyz,0.0)).xyz);key.color=texelFetch(source_local_lights,ivec2(1,10),0).rgb;key.visible=true;RE_Direct_Physical(key,vec3(0.0),normal,view,normal,material,reflected);
 }
 diffuse=reflected.directDiffuse;specular=reflected.directSpecular;
}
vec3 sourceDirectRadiance(vec3 base,float metal,float rough,vec3 normal,vec3 unperturbed,vec3 view,vec3 light_direction,vec2 source_fragcoord,vec3 geometry_position,mat4 view_matrix,int camera_mask){vec3 diffuse,specular;sourceDirectTerms(base,metal,rough,0.0,normal,unperturbed,view,light_direction,source_fragcoord,geometry_position,view_matrix,camera_mask,diffuse,specular);return diffuse+specular;}
