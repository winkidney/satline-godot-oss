extends RefCounted
static func apply(game,mode:String)->void:
 var flip_projection=mode.ends_with("-projection")
 if flip_projection:mode=mode.trim_suffix("-projection")
 if mode.begins_with("triangle-"):_triangle_mesh(game)
 for record in game.source_scene.source.materials:
  if not flip_projection and mode not in ["coverage","coverage-flat","triangle-mask","triangle-rest","triangle-domain"] and record.name!="pac9_anodised":continue
  var material=game.source_scene.materials[record.id]
  if not material is ShaderMaterial or material.shader==null:continue
  var shader=material.shader
  var code=shader.code.replace("void fragment(){","void fragment(){vec3 diagnostic_direct=vec3(0),diagnostic_indirect=vec3(0);")
  code=code.replace("EMISSION+=detail_diffuse*source_weapon_occlusion+detail_specular*(source_weapon_occlusion*source_weapon_occlusion);","diagnostic_indirect=detail_specular*(source_weapon_occlusion*source_weapon_occlusion);")
  code=code.replace("EMISSION+=detail_diffuse*mix(1.0,source_weapon_occlusion,.35)+detail_specular*mix(1.0,source_weapon_occlusion,.6);","diagnostic_direct=detail_specular*mix(1.0,source_weapon_occlusion,.6);")
  if mode in ["inputs","grain","noise","domain","coverage","triangle-domain"]:
   var detail=FileAccess.get_file_as_string("res://shaders/source_weapon_detail.gdshaderinc").replace("detail_debug=vec4(dLo,dMid,dGr,dDrop);","detail_debug=vec4(step(-.03,dP.x),1.-step(-.03,dP.x),0.,0.);" if mode=="coverage" else "detail_debug=vec4(dQ*34.,0.);" if mode in ["domain","triangle-domain"] else "detail_debug=vec4(dLo,dMid,dRun,dWet);" if mode=="noise" else "detail_debug=vec4(dGr+.5,dNear,dDrop,dRun);" if mode=="grain" else "detail_debug=vec4(dPx*1000.,dNear,dWet,dRun);")
   code=code.replace('#include "res://shaders/source_weapon_detail.gdshaderinc"',detail)
   code=code.replace("void fragment(){", "void fragment(){vec3 diagnostic_values=vec3(0);")
   code=code.replace("NORMAL=sourceWeaponBump(normalize(NORMAL),view_pos,source_weapon_height);", "diagnostic_values=detail_debug.xyz;NORMAL=sourceWeaponBump(normalize(NORMAL),view_pos,source_weapon_height);")
  var output="diagnostic_values" if mode in ["inputs","grain","noise","domain","coverage","triangle-domain"] else "normalize(NORMAL)*.5+.5" if mode=="normal" else "vec3(clamp(rr,.045,1.0))" if mode=="roughness" else "diagnostic_direct" if mode=="direct-specular" else "diagnostic_indirect"
  if mode.begins_with("triangle-"):
   if record.name=="pac9_anodised":
    code=code.replace("void vertex(){","varying flat float probe_id;\nvoid vertex(){probe_id=CUSTOM1.x;")
    output="vec3(probe_id==607.?1.:0.,probe_id==339.?1.:0.,probe_id==171.?1.:0.)"
    if mode=="triangle-confirm":output="vec3(probe_id==614.?1.:0.,0.,0.)"
    if mode=="triangle-rest":output="vec3(probe_id==612.?1.:0.,probe_id==613.?1.:0.,(probe_id!=607.&&probe_id!=339.&&probe_id!=171.&&probe_id!=612.&&probe_id!=613.)?1.:0.)"
    if mode=="triangle-domain":output="probe_id==339.?diagnostic_values:vec3(0.)"
   else:output="vec3(0)"
  if mode=="coverage-flat":
   if record.name=="pac9_anodised":
    code=code.replace("void vertex(){","varying flat float coverage_face;\nvoid vertex(){coverage_face=step(-.03,VERTEX.x);")
    output="vec3(coverage_face,1.-coverage_face,0.)"
   else:output="vec3(0,0,1)"
  if mode=="coverage" and record.name!="pac9_anodised":output="vec3(0,0,1)"
  var start=code.find("void fragment()")
  if start<0:continue
  var end=code.find("{",start);var depth=1;end+=1
  while end<code.length() and depth>0:
   if code[end]=="{":depth+=1
   elif code[end]=="}":depth-=1
   end+=1
  end-=1
  code=code.substr(0,end)+"ALBEDO=vec3(0);METALLIC=0.;SPECULAR=0.;ROUGHNESS=1.;IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);EMISSION="+output+";"+code.substr(end)
  if flip_projection:
   assert(code.contains("void vertex(){"),"Projection diagnostic requires explicit vertex entry")
   code=code.replace("void vertex(){","void vertex(){PROJECTION_MATRIX[1][1]=-PROJECTION_MATRIX[1][1];")
   code=code.replace("FRONT_FACING","(!FRONT_FACING)")
   code=code.replace("cull_front","cull_temporary").replace("cull_back","cull_front").replace("cull_temporary","cull_back")
  var variant=Shader.new();variant.code=code;variant.set_meta("source_shader_path",shader.get_meta("source_shader_path",shader.resource_path));material.shader=variant

static func _triangle_mesh(game)->void:
 for record in game.source_scene.source.nodes:
  if not record.has("materials") or record.materials.is_empty():continue
  var node=game.source_scene.source_nodes[record.id]
  if not node is MeshInstance3D:continue
  var material=node.get_active_material(0)
  var selected=false
  for m in game.source_scene.source.materials:
   if m.id in record.materials and m.name=="pac9_anodised":selected=true
  if not selected:continue
  assert(node.mesh.get_surface_count()==1)
  var arrays=node.mesh.surface_get_arrays(0)
  var count=arrays[Mesh.ARRAY_VERTEX].size()
  assert(count==50550 and arrays[Mesh.ARRAY_CUSTOM1]==null)
  var ids=PackedFloat32Array();ids.resize(count*4)
  for i in count:ids[i*4]=floori(i/3.0)
  arrays[Mesh.ARRAY_CUSTOM1]=ids
  var flags=0
  for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<shift
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,material)
  node.mesh=mesh
