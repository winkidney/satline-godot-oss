#include "res://shaders/source_cube_uv.gdshaderinc"
#include "res://shaders/source_indirect_brdf.gdshaderinc"
uniform sampler2D source_ibl_sky:filter_linear,repeat_disable;
uniform sampler2D source_ibl_room:filter_linear,repeat_disable;
uniform bool source_ibl_ready=false;
uniform bool source_ibl_radiance_enabled=true;
uniform bool source_ibl_explicit_room=false;
uniform float source_ibl_explicit_intensity=1.0;
uniform bool source_ibl_view_room=false;
uniform float source_ibl_view_fill=1.1;
instance uniform bool source_ibl_viewmodel:instance_index(10)=false;
vec3 sourceIblSample(bool room,vec3 direction,float roughness){
 if(room)return sourceCubeTexture(source_ibl_room,direction,roughness,vec2(.0026041666666666665,.001953125),7.0).rgb;
 return sourceCubeTexture(source_ibl_sky,direction,roughness,vec2(.0013020833333333333,.0009765625),8.0).rgb;
}
float sourceIblRoughness(float rough,vec3 unperturbed){vec3 dxy=max(abs(dFdx(unperturbed)),abs(dFdy(unperturbed)));return min(max(rough,.0525)+max(max(dxy.x,dxy.y),dxy.z),1.0);}
void sourceIblTerms(vec3 base,float metal,float rough,float wet_f0,vec3 normal,vec3 unperturbed,vec3 view,mat4 inverse_view,float ao,float env_scale,vec3 radiance_override,float override_weight,out vec3 diffuse,out vec3 specular){
 bool room=source_ibl_explicit_room||(source_ibl_viewmodel&&source_ibl_view_room);
 float intensity=source_ibl_explicit_room?source_ibl_explicit_intensity:(source_ibl_viewmodel?(source_ibl_view_room?1.0:2.0)*source_ibl_view_fill:2.0);
 
 PhysicalMaterial material;material.diffuseColor=base*(1.0-metal);material.roughness=sourceIblRoughness(rough,unperturbed);material.specularColor=mix(mix(vec3(.04),base,metal),vec3(.075),wet_f0);material.specularF90=1.0;
 vec3 world_normal=normalize((inverse_view*vec4(normal,0.0)).xyz);
 vec3 reflect_vector=normalize(mix(reflect(-view,normal),normal,material.roughness*material.roughness));reflect_vector=normalize((inverse_view*vec4(reflect_vector,0.0)).xyz);
 vec3 irradiance=3.141592653589793*sourceIblSample(room,world_normal,1.0)*intensity;
 vec3 radiance=sourceIblSample(room,reflect_vector,material.roughness)*intensity;
 radiance=mix(radiance,radiance_override,override_weight)*env_scale;irradiance*=env_scale;
 ReflectedLight reflected;reflected.directDiffuse=vec3(0);reflected.directSpecular=vec3(0);reflected.indirectDiffuse=vec3(0);reflected.indirectSpecular=vec3(0);
 RE_IndirectSpecular_Physical(radiance,irradiance,vec3(0),vec3(0),normal,view,normal,material,reflected);
 reflected.indirectDiffuse*=ao;reflected.indirectSpecular*=computeSpecularOcclusion(clamp(dot(normal,view),0.0,1.0),ao,material.roughness);
 diffuse=reflected.indirectDiffuse;specular=reflected.indirectSpecular;
}

vec3 sourceIblRadiance(vec3 base,float metal,float rough,vec3 normal,vec3 unperturbed,vec3 view,mat4 inverse_view,float ao){vec3 diffuse,specular;sourceIblTerms(base,metal,rough,0.0,normal,unperturbed,view,inverse_view,ao,1.0,vec3(0),0.0,diffuse,specular);return diffuse+specular;}
