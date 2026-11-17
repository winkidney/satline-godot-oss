extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-bump-reference.json"));var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,0,3);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.current=true
 var instance=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(2,2);instance.mesh=quad;viewport.add_child(instance);var material=ShaderMaterial.new();material.shader=load("res://shaders/source_weapon_bump_spatial_probe.gdshader");instance.material_override=material
 var reports=[];var failures=[];var channels=0
 for i in reference.cases.size():
  var sample=reference.cases[i];material.set_shader_parameter("uScale",Vector2(sample.scale[0],sample.scale[1]));material.set_shader_parameter("uFace",sample.face);material.set_shader_parameter("uGradient",Vector2(sample.gradient[0],sample.gradient[1]))
  for warm in 3:await process_frame;RenderingServer.force_draw(false)
  var image=viewport.get_texture().get_image();var maximum=0.0
  for y in range(16,48):
   for x in range(16,48):
    var color=image.get_pixel(x,y)
    for channel in 3:
     channels+=1;maximum=maxf(maximum,absf(color[channel]-sample.pixels[channel]))
  reports.append({"case":i,"maximum_error":maximum})
  if maximum>.001:failures.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":channels,"failures":failures,"scope":"Actual spatial QuadMesh/Camera3D with Vulkan projection and fragment derivatives,production weaponBump vs32 literal original Three height-gradient/face/mirror cases;constant planar gradients andinterior pixels. Does not cover source mesh perspective interpolation or procedural heights."};FileAccess.open("res://evidence/weapon-bump-spatial-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
