from pathlib import Path
HEADER='#include "res://shaders/source_ibl_surface.gdshaderinc"'
def inject_file(path):
 path=Path(path);shader=path.read_text();kind=path.stem
 if HEADER in shader:return
 if kind=="ground" and " // SOURCE_PLANAR_RADIANCE_END" not in shader:return
 shader=shader.replace('#include "res://shaders/source_sun_surface.gdshaderinc"','#include "res://shaders/source_sun_surface.gdshaderinc"\n'+HEADER)
 if kind=='ground':
  shader=shader.replace(' // SOURCE_PLANAR_RADIANCE_BEGIN',' vec3 source_planar_rgb=vec3(0.0);float source_planar_weight=0.0;\n // SOURCE_PLANAR_RADIANCE_BEGIN')
  shader=shader.replace('RADIANCE = vec4(pr,pw);','source_planar_rgb=pr;source_planar_weight=pw;')
  shader=shader.replace('float r = ROUGHNESS;','float r = source_ibl_ready?sourceIblRoughness(gRough,source_non_perturbed):ROUGHNESS;')
  marker=' // SOURCE_PLANAR_RADIANCE_END'
  block='\n if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled){vec3 diffuse,specular;sourceIblTerms(ALBEDO,0.0,gRough,max(gPuddle,gSoak*.5),normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0,1.0,source_planar_rgb,source_planar_weight,diffuse,specular);EMISSION+=diffuse+specular;}}\n else RADIANCE=vec4(source_planar_rgb,source_planar_weight);\n'
  assert marker in shader;shader=shader.replace(marker,marker+block)
 elif kind=='sea':
  marker='\n FOG='
  block='\n if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled){vec3 diffuse,specular;sourceIblTerms(ALBEDO,0.0,gRough,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0,gOcc,vec3(0),0.0,diffuse,specular);EMISSION+=diffuse+specular;}}\n'
  assert marker in shader;shader=shader.replace(marker,block+marker)
 elif kind=='arms':
  index=shader.rfind('}');block='\n if(source_ibl_ready){IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);if(source_ibl_radiance_enabled)EMISSION+=sourceIblRadiance(ALBEDO,0.0,armRough,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),INV_VIEW_MATRIX,1.0);}\n'
  shader=shader[:index]+block+shader[index:]
 else:raise ValueError(kind)
 path.write_text(shader)
