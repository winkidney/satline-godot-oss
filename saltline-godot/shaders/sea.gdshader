shader_type spatial;
render_mode diffuse_lambert,specular_schlick_ggx;
#include "res://shaders/source_raster_coords.gdshaderinc"
#include "res://shaders/source_sun_surface.gdshaderinc"
#include "res://shaders/source_ibl_surface.gdshaderinc"
#include "res://shaders/source_direct_surface.gdshaderinc"
uniform float uTime=0.0;
uniform sampler2D uDetail:filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D uDetailN:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec3 uHazeA=vec3(.136,.187,.255);
uniform vec3 uHazeB=vec3(.76,.44,.224);
uniform vec3 uSunDirW=vec3(.9163473615,.2250853235,.3311255204);
varying vec3 vGWorld;
varying float vSAmp;
varying vec3 sea_camera;
varying float sea_glitter;
vec4 sourceSample(sampler2D tex,vec2 uv){return texture(tex,vec2(uv.x,1.0-uv.y));}
void vertex(){
 sea_camera=INV_VIEW_MATRIX[3].xyz;
  vec3 swp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  vSAmp = 1.0 - smoothstep(50.0, 220.0, distance(swp.xz, vec2(30.0, 0.0)));
  vec3 sdisp = vec3(0.0);
  { float ph = 0.66139 * dot(vec2(-0.92069, 0.39029), swp.xz) - 2.54720 * uTime; sdisp.y += 0.06000 * sin(ph); sdisp.xz += vec2(-0.92069, 0.39029) * (0.03600 * cos(ph)); }
  { float ph = 1.10231 * dot(vec2(-0.75071, -0.66063), swp.xz) - 3.28842 * uTime; sdisp.y += 0.04000 * sin(ph); sdisp.xz += vec2(-0.75071, -0.66063) * (0.02400 * cos(ph)); }
  { float ph = 1.90400 * dot(vec2(-0.99273, 0.12033), swp.xz) - 4.32183 * uTime; sdisp.y += 0.02600 * sin(ph); sdisp.xz += vec2(-0.99273, 0.12033) * (0.01560 * cos(ph)); }
  { float ph = 3.14159 * dot(vec2(-0.49828, 0.86701), swp.xz) - 5.55149 * uTime; sdisp.y += 0.01600 * sin(ph); sdisp.xz += vec2(-0.49828, 0.86701) * (0.00960 * cos(ph)); }
  VERTEX += sdisp * vSAmp;
  vGWorld = swp;
 source_sun_shadow_coord=source_sun_shadow_matrix*vec4((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);
}
void fragment(){
 vec3 source_non_perturbed=normalize(NORMAL);
 float gRough,gOcc,gSDist,gSpark;vec2 gNxz;vec4 diffuseColor=vec4(1.0);
{
  vec2 sxz = vGWorld.xz;
  float sd = length(sea_camera - vGWorld); gSDist = sd;
  vec2 slopeA = vec2(0.0), slopeB = vec2(0.0);
  slopeA += vec2(-0.92069, 0.39029) * (0.03968 * cos(0.66139 * dot(vec2(-0.92069, 0.39029), sxz) - 2.54720 * uTime));
  slopeA += vec2(-0.75071, -0.66063) * (0.04409 * cos(1.10231 * dot(vec2(-0.75071, -0.66063), sxz) - 3.28842 * uTime));
  slopeA += vec2(-0.99273, 0.12033) * (0.04950 * cos(1.90400 * dot(vec2(-0.99273, 0.12033), sxz) - 4.32183 * uTime));
  slopeA += vec2(-0.49828, 0.86701) * (0.05027 * cos(3.14159 * dot(vec2(-0.49828, 0.86701), sxz) - 5.55149 * uTime));
  slopeB += vec2(-0.80000, 0.60000) * (0.09593 * cos(4.79632 * dot(vec2(-0.80000, 0.60000), sxz) - 6.85944 * uTime));
  slopeB += vec2(-0.95067, -0.31022) * (0.10598 * cos(7.57010 * dot(vec2(-0.95067, -0.31022), sxz) - 8.61758 * uTime));
  slopeB += vec2(-0.34894, -0.93715) * (0.11023 * cos(11.02313 * dot(vec2(-0.34894, -0.93715), sxz) - 10.39889 * uTime));
  slopeB += vec2(-0.60000, 0.80000) * (0.11278 * cos(16.11073 * dot(vec2(-0.60000, 0.80000), sxz) - 12.57165 * uTime));
  slopeB += vec2(-0.99875, 0.04994) * (0.11636 * cos(23.27106 * dot(vec2(-0.99875, 0.04994), sxz) - 15.10924 * uTime));
  slopeB += vec2(0.30113, 0.95358) * (0.08021 * cos(13.36848 * dot(vec2(0.30113, 0.95358), sxz) - 11.45185 * uTime));
  slopeB += vec2(-0.86013, -0.51008) * (0.10472 * cos(29.91993 * dot(vec2(-0.86013, -0.51008), sxz) - 17.13227 * uTime));
  float nearB = 1.0 - smoothstep(25.0, 110.0, sd);
  vec2 t1 = sourceSample(uDetailN, sxz * 0.113 + uTime * vec2(-0.021, 0.009)).ba - 0.5;
  vec2 t2 = sourceSample(uDetailN, sxz * 0.031 + uTime * vec2(-0.007, -0.004)).ba - 0.5;
  vec2 t3 = sourceSample(uDetailN, sxz.yx * 0.39 + uTime * vec2(0.031, -0.027)).ba - 0.5;
  gNxz = slopeA * vSAmp + slopeB * nearB + t1 * 0.2 + t2 * 0.24 + t3 * 0.1 * nearB;
  // foam / scum along the quay wall (x = 30) and around the moored hull x[33,49] z[-60,-9]
  float dq = sxz.x - 30.0;
  vec2 hq = abs(sxz - vec2(41.0, -34.5)) - vec2(4.0, 21.5);
  float dh = length(max(hq, 0.0)) + min(max(hq.x, hq.y), 0.0) - 4.0;
  float de = min(dq, dh);
  vec4 fn = sourceSample(uDetail, sxz * 0.41 + uTime * vec2(-0.012, 0.007));
  vec4 fn2 = sourceSample(uDetail, sxz * 0.093 + uTime * vec2(0.004, 0.003));
  float band = 1.0 - smoothstep(0.0, 0.2 + fn2.g * fn2.g * 2.2, de);
  float foam = clamp(band * smoothstep(0.5, 0.68, fn.a * 0.55 + fn.r * 0.25 + fn2.g * 0.3 + band * 0.2), 0.0, 1.0) * step(-0.3, de);
  float scum = (1.0 - smoothstep(0.0, 5.0, de)) * smoothstep(0.4, 0.7, fn2.g);
  vec3 alb = vec3(0.0045, 0.013, 0.017);
  alb = mix(alb, vec3(0.03, 0.04, 0.034), scum * 0.6);
  alb = mix(alb, vec3(0.3, 0.32, 0.3), foam * 0.7);
  diffuseColor.rgb *= alb;
  // wind structure: broad cat's-paw patches (ruffled, darker, duller) between calmer slicks, plus long swell shading
  vec4 fn3 = sourceSample(uDetail, sxz * 0.0123 + uTime * vec2(0.0016, 0.0011));
  float gust = smoothstep(0.38, 0.62, fn2.g * 0.45 + fn3.g * 0.75 - 0.1);
  float swell = sin(dot(sxz, vec2(-0.118, 0.05)) - uTime * 0.55 + fn3.a * 5.0) * 0.5 + 0.5;
  gNxz = gNxz * mix(0.4, 1.35, gust) + vec2(-0.92, 0.39) * (swell - 0.5) * 0.07;
  gSpark = mix(0.55, 1.0, swell) * mix(1.0, 0.6, gust);
  diffuseColor.rgb *= mix(1.0, 0.6, gust);
  gRough = mix(mix(0.1, 0.32, smoothstep(12.0, 380.0, sd)) * mix(0.62, 1.5, gust), 0.65, max(foam, scum * 0.3));
  gNxz *= 1.0 - foam * 0.6;
  gOcc = mix(0.3, 1.0, smoothstep(0.0, 8.0, de)) * mix(0.8, 1.05, swell);
}

 ALBEDO=diffuseColor.rgb;ROUGHNESS=gRough;METALLIC=0.0;SPECULAR=.5;
 NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(vec3(-gNxz.x,1.0,-gNxz.y)));
 AO=clamp(gOcc,0.0,1.0);AO_LIGHT_AFFECT=0.0;
 vec3 sdir=normalize(vGWorld-sea_camera);
 float az=max(dot(normalize(sdir.xz+vec2(1e-5)),normalize(uSunDirW.xz)),0.0);
 sea_glitter=gSpark*mix(.3,1.0,az*az*az); if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready)){vec3 diffuse,specular;sourceDirectTerms(ALBEDO,0.0,gRough,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,sourceRasterPixel(FRAGCOORD.xy,VIEWPORT_SIZE,SOURCE_RASTER_Y_UP),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS),diffuse,specular);EMISSION+=diffuse+min(specular,vec3(40.0))*sea_glitter;}

 if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled){vec3 diffuse,specular;sourceIblTerms(ALBEDO,0.0,gRough,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0,gOcc,vec3(0),0.0,diffuse,specular);EMISSION+=diffuse+specular;}}

 FOG=vec4(mix(uHazeA,uHazeB,pow(az,3.0)),smoothstep(220.0,860.0,gSDist)*.8);
}
void light(){
 float nl=max(dot(NORMAL,LIGHT),0.0),nv=max(dot(NORMAL,VIEW),1e-5);
 vec3 half_vector=normalize(LIGHT+VIEW);
 float nh=max(dot(NORMAL,half_vector),0.0),vh=max(dot(VIEW,half_vector),0.0);
 float a=ROUGHNESS*ROUGHNESS,a2=a*a;
 float den=nh*nh*(a2-1.0)+1.0;
 float distribution=a2/(3.14159265359*den*den);
 float visibility=.5/max(nl*sqrt(a2+(1.0-a2)*nv*nv)+nv*sqrt(a2+(1.0-a2)*nl*nl),1e-6);
 vec3 fresnel=vec3(.04)+vec3(.96)*exp2((-5.55473*vh-6.98316)*vh);
 DIFFUSE_LIGHT+=LIGHT_COLOR*ATTENUATION*nl/3.14159265359;
 vec3 direct_specular=LIGHT_COLOR*ATTENUATION*nl*distribution*visibility*fresnel;
 SPECULAR_LIGHT+=min(direct_specular,vec3(40.0))*sea_glitter;
}
