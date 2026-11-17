#include "res://shaders/source_sun_brdf.gdshaderinc"
#include "res://shaders/source_sun_pcss.gdshaderinc"
uniform sampler2D source_sun_shadow:filter_nearest,repeat_disable;
uniform mat4 source_sun_shadow_matrix;
uniform vec2 source_sun_shadow_size=vec2(4096.0);
uniform vec3 source_sun_direction=vec3(.9163473614874841,.22508532350948027,.33112552036283543);
uniform bool source_sun_ready=false;
instance uniform bool source_sun_active=false;
instance uniform bool source_sun_receive_shadow=true;
varying vec4 source_sun_shadow_coord;
void sourceSunTerms(vec3 base,float metal,float rough,float wet_f0,vec3 normal,vec3 unperturbed,vec3 view,vec3 light_direction,vec2 source_fragcoord,out vec3 diffuse,out vec3 specular){
 vec3 dxy=max(abs(dFdx(unperturbed)),abs(dFdy(unperturbed)));float geometry_roughness=max(max(dxy.x,dxy.y),dxy.z);
 PhysicalMaterial material;material.diffuseColor=base*(1.0-metal);material.roughness=min(max(rough,.0525)+geometry_roughness,1.0);material.specularColor=mix(mix(vec3(.04),base,metal),vec3(.075),wet_f0);material.specularF90=1.0;
 float visibility=1.0;if(source_sun_receive_shadow)visibility=getShadow(source_sun_shadow,source_sun_shadow_size,1.0,-.00012,1.0,source_sun_shadow_coord,source_fragcoord);
 IncidentLight light;light.direction=normalize(light_direction);light.color=vec3(1.0,.72,.42)*9.0*visibility;light.visible=true;
 ReflectedLight reflected;reflected.directDiffuse=vec3(0.0);reflected.directSpecular=vec3(0.0);reflected.indirectDiffuse=vec3(0.0);reflected.indirectSpecular=vec3(0.0);
 RE_Direct_Physical(light,vec3(0.0),normal,view,normal,material,reflected);diffuse=reflected.directDiffuse;specular=reflected.directSpecular;
}

vec3 sourceSunRadiance(vec3 base,float metal,float rough,vec3 normal,vec3 unperturbed,vec3 view,vec3 light_direction,vec2 source_fragcoord){vec3 diffuse,specular;sourceSunTerms(base,metal,rough,0.0,normal,unperturbed,view,light_direction,source_fragcoord,diffuse,specular);return diffuse+specular;}
