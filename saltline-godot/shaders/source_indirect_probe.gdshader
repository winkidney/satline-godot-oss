shader_type canvas_item;
render_mode unshaded,blend_disabled;
#define USE_AOMAP
#define USE_ENVMAP
#define STANDARD
#include "res://shaders/source_sun_brdf.gdshaderinc"
#include "res://shaders/source_indirect_brdf.gdshaderinc"
uniform vec3 uBase;uniform vec3 uNormal;uniform vec3 uView;uniform vec3 uRadiance;uniform vec3 uAmbient;uniform vec3 uEnvIrr;
uniform float uMetal;uniform float uRough;uniform float uWetSpec;uniform float uAo;
void fragment(){PhysicalMaterial material;material.diffuseColor=uBase*(1.0-uMetal);material.roughness=uRough;material.specularColor=mix(mix(vec3(.04),uBase,uMetal),vec3(.075),uWetSpec);material.specularF90=1.0;vec3 geometryNormal=normalize(uNormal),geometryViewDir=normalize(uView);ReflectedLight reflectedLight;reflectedLight.directDiffuse=vec3(0);reflectedLight.directSpecular=vec3(0);reflectedLight.indirectDiffuse=vec3(0);reflectedLight.indirectSpecular=vec3(0);RE_IndirectDiffuse_Physical(uAmbient,vec3(0),geometryNormal,geometryViewDir,geometryNormal,material,reflectedLight);RE_IndirectSpecular_Physical(uRadiance,uEnvIrr,vec3(0),vec3(0),geometryNormal,geometryViewDir,geometryNormal,material,reflectedLight);
#ifdef USE_AOMAP
	float ambientOcclusion = ( uAo - 1.0 ) * 1.0 + 1.0;
	reflectedLight.indirectDiffuse *= ambientOcclusion;
	#if defined( USE_CLEARCOAT ) 
		clearcoatSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_SHEEN ) 
		sheenSpecularIndirect *= ambientOcclusion;
	#endif
	#if defined( USE_ENVMAP ) && defined( STANDARD )
		float dotNV = saturate( dot( geometryNormal, geometryViewDir ) );
		reflectedLight.indirectSpecular *= computeSpecularOcclusion( dotNV, ambientOcclusion, material.roughness );
	#endif
#endif
COLOR=vec4(FRAGCOORD.x<1.0?reflectedLight.indirectDiffuse:reflectedLight.indirectSpecular,1.0);}
