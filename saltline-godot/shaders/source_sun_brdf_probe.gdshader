shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://shaders/source_sun_brdf.gdshaderinc"
float source_half_rne(float value){
 if(value<0.00006103515625){float scaled=value*16777216.0;float base=floor(scaled);float f=fract(scaled);return (base+((f>0.5 || (f==0.5 && mod(base,2.0)>0.0))?1.0:0.0))/16777216.0;}
 uint bits=floatBitsToUint(value);return uintBitsToFloat((bits+4095u+((bits>>13u)&1u))&4294959104u);
}
uniform vec3 uBase;uniform vec3 uNormal;uniform vec3 uView;uniform vec3 uLight;uniform float uMetal;uniform float uRough;uniform float uGeometryRough;uniform float uWetSpec;uniform float uVisibility;
void fragment(){PhysicalMaterial material;material.diffuseColor=uBase*(1.0-uMetal);material.roughness=min(max(uRough,.0525)+uGeometryRough,1.0);material.specularColor=mix(mix(vec3(.04),uBase,uMetal),vec3(.075),uWetSpec);material.specularF90=1.0;IncidentLight light;light.direction=normalize(uLight);light.color=vec3(1.0,.72,.42)*9.0*uVisibility;light.visible=true;ReflectedLight reflected;reflected.directDiffuse=vec3(0.0);reflected.directSpecular=vec3(0.0);reflected.indirectDiffuse=vec3(0.0);reflected.indirectSpecular=vec3(0.0);RE_Direct_Physical(light,vec3(0.0),normalize(uNormal),normalize(uView),normalize(uNormal),material,reflected);vec3 result=UV.x<.5?reflected.directDiffuse:reflected.directSpecular;COLOR=vec4(source_half_rne(result.r),source_half_rne(result.g),source_half_rne(result.b),1.0);}
