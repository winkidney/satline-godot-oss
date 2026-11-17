shader_type canvas_item;
render_mode unshaded,blend_disabled;
#include "res://shaders/source_sun_brdf.gdshaderinc"
#include "res://shaders/source_local_light_math.gdshaderinc"
uniform float uDistance;uniform float uCutoff;uniform float uDecay;uniform float uAngle;
void fragment(){float d=max(uDistance,.000001);vec3 position=vec3(sqrt(max(0.0,1.0-uAngle*uAngle))*d,uAngle*d,0.0);SourcePointLight point;point.position=position;point.color=vec3(.7,.4,.2);point.distance=uCutoff;point.decay=uDecay;IncidentLight p;sourcePointLightInfo(point,vec3(0),p);SourceSpotLight spot;spot.position=position;spot.direction=vec3(0,1,0);spot.color=vec3(1);spot.distance=uCutoff;spot.decay=uDecay;spot.coneCos=.92;spot.penumbraCos=.97;IncidentLight s;sourceSpotLightInfo(spot,vec3(0),s);float attenuation=sourceDistanceAttenuation(uDistance,uCutoff,uDecay),cone=sourceSpotAttenuation(.92,.97,uAngle);COLOR=FRAGCOORD.x<1.0?vec4(attenuation,p.color.r,p.visible?1.0:0.0,1.0):vec4(cone,s.color.b,s.visible?1.0:0.0,1.0);}
