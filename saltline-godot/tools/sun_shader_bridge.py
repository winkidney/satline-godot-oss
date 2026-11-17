from pathlib import Path
HEADER='#include "res://shaders/source_sun_surface.gdshaderinc"\n#include "res://shaders/source_direct_surface.gdshaderinc"'
SUN_BLOCKS={'ground': ' if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready)){vec3 diffuse,specular;sourceDirectTerms(ALBEDO,0.0,gRough,max(gPuddle,gSoak*.5),normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,vec2(FRAGCOORD.x,VIEWPORT_SIZE.y-FRAGCOORD.y),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS),diffuse,specular);EMISSION+=diffuse+min(specular,vec3(40.0));}', 'sea': ' if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready)){vec3 diffuse,specular;sourceDirectTerms(ALBEDO,0.0,gRough,0.0,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,vec2(FRAGCOORD.x,VIEWPORT_SIZE.y-FRAGCOORD.y),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS),diffuse,specular);EMISSION+=diffuse+min(specular,vec3(40.0))*sea_glitter;}', 'arms': ' if((source_sun_active&&source_sun_ready)||(source_local_active&&source_local_ready))EMISSION+=sourceDirectRadiance(ALBEDO,0.0,armRough,normalize(NORMAL),source_non_perturbed,normalize(-VERTEX),(VIEW_MATRIX*vec4(source_sun_direction,0.0)).xyz,vec2(FRAGCOORD.x,VIEWPORT_SIZE.y-FRAGCOORD.y),VERTEX,VIEW_MATRIX,sourceLocalCameraMask(CAMERA_VISIBLE_LAYERS));'}
def inject_file(path):
 path=Path(path);shader=path.read_text();kind=path.stem
 if HEADER.split('\n',1)[0] in shader:
  assert '#include "res://shaders/source_direct_surface.gdshaderinc"' in shader,'Existing sun shader needs direct migration before reinjection'
  from ibl_shader_bridge import inject_file as inject_ibl
  inject_ibl(path);return
 lines=shader.splitlines();lines.insert(2,HEADER);shader='\n'.join(lines)+'\n';shader=shader.replace('void fragment(){','void fragment(){\n vec3 source_non_perturbed=normalize(NORMAL);')
 if kind=='ground':
  shader=shader.replace('render_mode cull_disabled;','render_mode cull_disabled,specular_occlusion_disabled;')
  shader=shader.replace('void vertex(){vGWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}','void vertex(){vGWorld=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;source_sun_shadow_coord=source_sun_shadow_matrix*vec4(vGWorld+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);}')
  index=shader.find(' // SOURCE_PLANAR_RADIANCE_BEGIN')
  if index<0:index=shader.rfind('}')
 elif kind=='sea':
  shader=shader.replace('  vGWorld = swp;','  vGWorld = swp;\n source_sun_shadow_coord=source_sun_shadow_matrix*vec4((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);')
  index=shader.index('\n FOG=')
 else:
  shader=shader.replace('v_view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;}','v_view_pos=(MODELVIEW_MATRIX*vec4(VERTEX,1.0)).xyz;source_sun_shadow_coord=source_sun_shadow_matrix*vec4((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+normalize(MODEL_NORMAL_MATRIX*NORMAL)*.02,1.0);}')
  index=shader.rfind('}')
 shader=shader[:index]+SUN_BLOCKS[kind]+'\n'+shader[index:];path.write_text(shader)
 from ibl_shader_bridge import inject_file as inject_ibl
 inject_ibl(path)
