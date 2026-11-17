float sourceLightPow4( float x ) { float x2 = x*x; return x2*x2; }

float sourceDistanceAttenuation( float lightDistance, float cutoffDistance, float decayExponent ) {
	float distanceFalloff = 1.0 / max( pow( lightDistance, decayExponent ), 0.01 );
	if ( cutoffDistance > 0.0 ) {
		distanceFalloff *= pow2( saturate( 1.0 - sourceLightPow4( lightDistance / cutoffDistance ) ) );
	}
	return distanceFalloff;
}

float sourceSpotAttenuation( float coneCosine, float penumbraCosine, float angleCosine ) {
	return smoothstep( coneCosine, penumbraCosine, angleCosine );
}

struct SourcePointLight {
		vec3 position;
		vec3 color;
		float distance;
		float decay;
	};

	void sourcePointLightInfo( SourcePointLight pointLight, vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = pointLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float lightDistance = length( lVector );
		light.color = pointLight.color;
		light.color *= sourceDistanceAttenuation( lightDistance, pointLight.distance, pointLight.decay );
		light.visible = ( light.color != vec3( 0.0 ) );
	}

struct SourceSpotLight {
		vec3 position;
		vec3 direction;
		vec3 color;
		float distance;
		float decay;
		float coneCos;
		float penumbraCos;
	};

	void sourceSpotLightInfo( SourceSpotLight spotLight, vec3 geometryPosition, out IncidentLight light ) {
		vec3 lVector = spotLight.position - geometryPosition;
		light.direction = normalize( lVector );
		float angleCos = dot( light.direction, spotLight.direction );
		float spotAttenuation = sourceSpotAttenuation( spotLight.coneCos, spotLight.penumbraCos, angleCos );
		if ( spotAttenuation > 0.0 ) {
			float lightDistance = length( lVector );
			light.color = spotLight.color * spotAttenuation;
			light.color *= sourceDistanceAttenuation( lightDistance, spotLight.distance, spotLight.decay );
			light.visible = ( light.color != vec3( 0.0 ) );
		} else {
			light.color = vec3( 0.0 );
			light.visible = false;
		}
	}
