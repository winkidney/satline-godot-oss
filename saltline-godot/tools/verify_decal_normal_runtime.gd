extends SceneTree
func _initialize()->void:call_deferred("verify")
func diagnostic(source:String)->String:
 source=source.replace("render_mode ","render_mode unshaded,")
 var at=source.find("void fragment(){");var begin=source.find("{",at);var end=begin+1;var depth=1
 while depth>0:
  if source.substr(end,1)=="{":depth+=1
  elif source.substr(end,1)=="}":depth-=1
  end+=1
 var fragment="void fragment(){vec3 error=uMode==0?local_n-uExpected:uMode==1?world_n-uExpected:source_sun_shadow_coord.xyz-(world_pos+uExpected*.02);ALBEDO=abs(error)*16384.0;EMISSION=vec3(0);ALPHA=1.0;}"
 return source.substr(0,at)+"\nuniform vec3 uExpected;uniform int uMode;\n"+fragment+source.substr(end)
func verify()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();scene.visible=false
 var failures=[];var enabled=0;var checks=0
 var record:Dictionary
 for value in scene.source.materials:
  if value.name=="fx_decals":record=value
 for id in scene.materials:
  var material=scene.materials[id]
  if material is ShaderMaterial:
   for uniform in material.shader.get_shader_uniform_list():
    if uniform.name=="source_exact_normal" and material.get_shader_parameter("source_exact_normal")==true:
     enabled+=1
     if id!=record.id:failures.append("exact normal enabled outside decal")
 checks+=1
 if enabled!=1:failures.append("production fx_decals exact normal binding")
 var viewport=SubViewport.new();viewport.size=Vector2i(16,16);viewport.own_world_3d=true;viewport.use_hdr_2d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var world=Node3D.new();viewport.add_child(world);var camera=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.2;camera.current=true
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED;environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=environment
 var decals=SaltlineDecals.new(scene);var mesh=decals.mesh;mesh.reparent(world,false);mesh.transform=Transform3D.IDENTITY
 var reports=[]
 for alpha in [false,true]:
  var copied=record.duplicate(true);copied.props.transparent=alpha
  var material=scene._material(copied);var shader=Shader.new();shader.code=diagnostic(material.shader.code);material.shader=shader;material.set_shader_parameter("source_exact_normal",true);material.set_shader_parameter("source_sun_shadow_matrix",Projection.IDENTITY);decals.material=material
  for normal in [Vector3.UP,Vector3(.3,.7,-.2).normalized(),Vector3(.001,.002,.003).normalized()]:
   decals.clear();decals.add(Vector3.ZERO,normal,"bullet_concrete",1,1,1)
   var expected:Vector3=decals.slots[0].normal;camera.position=expected*2;camera.look_at(Vector3.ZERO,Vector3.FORWARD if absf(expected.y)>.9 else Vector3.UP)
   var white=ShaderMaterial.new();var white_shader=Shader.new();white_shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(1);}";white.shader=white_shader;mesh.material_override=white
   for warm in 4:await process_frame;RenderingServer.force_draw(false)
   var white_image=viewport.get_texture().get_image();var white_pixel=white_image.get_pixel(8,8);checks+=1
   if white_pixel.r<.5:failures.append({"calibration":"white decal not rendered","visible":mesh.is_visible_in_tree(),"layers":mesh.layers,"camera_mask":camera.cull_mask,"camera_current":camera.current,"position":str(mesh.global_position),"normal":str(expected)})
   white_image.save_png("res://evidence/decal-normal-probe-white.png")
   mesh.material_override=null
   for mode in 3:
    material.set_shader_parameter("uExpected",expected if mode==0 else expected.normalized());material.set_shader_parameter("uMode",mode)
    for exact in [true,false] if mode==0 else [true]:
     material.set_shader_parameter("source_exact_normal",exact)
     for warm in 4:await process_frame;RenderingServer.force_draw(false)
     var pixel=viewport.get_texture().get_image().get_pixel(8,8);var maximum=maxf(pixel.r,maxf(pixel.g,pixel.b));checks+=1
     if exact and (not is_finite(maximum) or maximum>.01):failures.append({"alpha":alpha,"normal":[expected.x,expected.y,expected.z],"mode":mode,"exact":exact,"scaled_error":maximum})
     if not exact and maximum<.05:failures.append({"control":"disabled path did not expose oct16 error","mode":mode,"value":maximum})
     reports.append({"alpha":alpha,"mode":mode,"exact":exact,"scaled_error":maximum})
 var report={"checks":checks,"enabled_source_materials":enabled,"samples":reports,"failures":failures,"scope":"Actual source material binding and actual decal CUSTOM2 mesh. Production Standard/alpha vertex retained, fragment replaced with amplified local/world/sun-offset diagnostics; exact-normal on plus off control. HDR target16x16; not full original shaded pixels."}
 FileAccess.open("res://evidence/decal-normal-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));scene.queue_free();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
