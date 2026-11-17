extends SceneTree
func _initialize()->void:
 ProjectSettings.set_setting("rendering/saltline/source_depth_24",true);call_deferred("run")
func material(mode:String,transparent:bool)->ShaderMaterial:
 var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded"+(",depth_draw_never" if transparent else "")+(","+mode if not mode.is_empty() else "")+";void fragment(){ALBEDO="+("vec3(0,1,0);ALPHA=.5;" if transparent else "vec3(0,0,1);")+"}";var result=ShaderMaterial.new();result.shader=shader;return result
func run()->void:
 root.disable_3d=true;var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.near=1;camera.far=3;camera.position=Vector3(0,0,3);viewport.add_child(camera);camera.current=true
 var bridge=load("res://tools/polygon_depth_bridge.gd").new();var compositor=Compositor.new();compositor.compositor_effects=[bridge];camera.compositor=compositor;bridge.prepare_size(viewport.size)
 var quad=QuadMesh.new();quad.size=Vector2(4,4);var base=MeshInstance3D.new();base.mesh=quad;base.position.z=1;viewport.add_child(base);base.material_override=material("",false);var decal=MeshInstance3D.new();decal.mesh=quad;viewport.add_child(decal);var materials={};var modes={"":0.0,"saltline_bias_world_2":4.0,"saltline_bias_world_4":8.0,"saltline_bias_weapon_3":120.0}
 for mode in modes:materials[mode]=material(mode,true)
 var reports=[];var failures=[]
 for msaa in [Viewport.MSAA_DISABLED,Viewport.MSAA_4X]:
  viewport.msaa_3d=msaa;decal.visible=false
  for warm in 6:await process_frame;RenderingServer.force_draw(false)
  var base_depth=bridge.output.get_image().get_pixel(32,32).r;decal.visible=true
  for gap in [2.0,16.0,64.0,256.0]:
   decal.position.z=1.0-gap*2.0/16777216.0
   for mode in modes:
    decal.material_override=materials[mode]
    for warm in 4:await process_frame;RenderingServer.force_draw(false)
    var color=viewport.get_texture().get_image().get_pixel(32,32);var actual_visible=color.g>.4;var expected_visible=modes[mode]>gap;var depth=bridge.output.get_image().get_pixel(32,32).r
    if actual_visible!=expected_visible or absf(depth-base_depth)>.00000001 or (actual_visible and (absf(color.g-.5)>.002 or absf(color.b-.5)>.002)):failures.append({"mode":mode,"gap":gap,"msaa":msaa,"expected_visible":expected_visible,"color":str(color),"depth_delta":depth-base_depth})
    reports.append({"mode":mode,"gap_q24":gap,"msaa":msaa,"expected_visible":expected_visible,"actual_visible":actual_visible,"depth_delta":depth-base_depth,"rgb":[color.r,color.g,color.b]})
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();var bindings=[];var objects=0;var original_count=0
 for record in scene.source.materials:
  var node_material=scene.materials[record.id];var enabled=bool(record.props.get("polygonOffset",false));var actual=str(node_material.get_meta("source_polygon_offset_mode",""))
  if enabled:
   original_count+=1;var weapon=(int(scene.source_material_masks.get(record.id,0))&2)!=0;var expected="saltline_bias_weapon_3" if weapon else "saltline_bias_world_"+str(int(-float(record.props.polygonOffsetFactor)))
   if actual!=expected:failures.append("material bias mapping "+record.id)
   bindings.append({"id":record.id,"name":record.name,"mode":actual})
  elif not actual.is_empty():failures.append("bias leaked to plain material "+record.id)
 for record in scene.source.nodes:
  for id in record.get("materials",[]):
   if not str(scene.materials[id].get_meta("source_polygon_offset_mode","")).is_empty():objects+=1;break
 if original_count!=48 or objects!=75:failures.append("original offset coverage")
 scene.source_polygon_supported=false
 if not scene._source_polygon_mode({"polygonOffset":true,"polygonOffsetFactor":-2,"polygonOffsetUnits":-2},1).is_empty():failures.append("unsupported D24 still enables D24 bias units")
 scene.source_polygon_supported=true
 var source_cases=[];viewport.size=Vector2i(256,256);bridge.prepare_size(viewport.size)
 for id in ["1b148cb5-cf27-4e1f-bb4b-555b80c09014","1f35ff0a-2a7c-4d04-a2ef-c088ea8b8a8d"]:
  var record={}
  for candidate in scene.source.nodes:
   if id in candidate.get("materials",[]):record=candidate;break
  var geometry=scene.geometry_records[record.geometry];var positions=scene._vec3(geometry.attributes.position);var center=scene.source_nodes[record.id].mesh.get_aabb().get_center();var normal=(positions[1]-positions[0]).cross(positions[2]-positions[0]).normalized();var size=scene.source_nodes[record.id].mesh.get_aabb().size
  camera.size=maxf(.05,maxf(size.x,maxf(size.y,size.z))*1.3);camera.position=center+normal*2;camera.look_at(center,Vector3.FORWARD if absf(normal.dot(Vector3.UP))>.98 else Vector3.UP);base.mesh=scene.source_nodes[record.id].mesh;decal.mesh=base.mesh;base.position=Vector3.ZERO;decal.position=-normal*(64.0 if id=="1f35ff0a-2a7c-4d04-a2ef-c088ea8b8a8d" else 2.0)*2.0/16777216.0
  var source_material:ShaderMaterial=scene.materials[id];var original_shader=source_material.shader;var parameters={}
  for uniform in original_shader.get_shader_uniform_list():parameters[uniform.name]=source_material.get_shader_parameter(uniform.name)
  var properties=scene.source.materials.filter(func(value):return value.id==id)[0].props.duplicate(true);properties.polygonOffset=false;var plain=scene._generic_shader(str(original_shader.get_meta("source_shader_path",original_shader.resource_path)),properties,int(scene.source_material_masks[id]));var images=[]
  decal.material_override=source_material
  for enabled in [false,true]:
   source_material.shader=original_shader if enabled else plain
   for key in parameters:source_material.set_shader_parameter(key,parameters[key])
   for warm in 6:await process_frame;RenderingServer.force_draw(false)
   images.append(viewport.get_texture().get_image())
  var changed=0;var maximum=0.0
  for y in 256:
   for x in 256:
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta)
    if delta>.001:changed+=1
  if changed<5:failures.append("original textured material hardware bias contribution "+id)
  source_cases.append({"material":id,"mesh":record.id,"changed_hdr_pixels":changed,"maximum_rgb_difference":maximum})
 var report={"profiles":reports,"bindings":bindings,"source_cases":source_cases,"source_materials":original_count,"source_objects":objects,"failures":failures,"scope":"Actual Forward+ transparent green alpha.5 overblue receiver,0/4xMSAA,fourbehindgaps verifies visibility/alpha/depthWrite=false. All195 loader mapping:48original offset materials/75meshes. Original decal/markings geometry+texture+productionshader additionally tested behindsame-geometry receiver,4xMSAA,only bias toggled withsame uniforms. Not full source perspective composite orweapon sharedworld depth-range quantization."};FileAccess.open("res://evidence/polygon-transparency-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"profiles":reports.size(),"source_cases":source_cases,"source_materials":original_count,"source_objects":objects,"failures":failures}));camera.compositor=null;compositor.compositor_effects.clear();bridge.dispose();base.material_override=null;decal.material_override=null;materials.clear();viewport.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
