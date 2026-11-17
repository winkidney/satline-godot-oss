extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport=SubViewport.new();viewport.size=Vector2i(128,128);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var scene=Node3D.new();viewport.add_child(scene)
 var camera=Camera3D.new();camera.position.z=2;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;scene.add_child(camera);camera.current=true
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.ambient_light_energy=0;camera.environment=environment
 var mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2.ONE;mesh.mesh=quad;scene.add_child(mesh)
 var source=FileAccess.get_file_as_string("res://shaders/sight_glass.gdshader");var shader=Shader.new();shader.code=source.left(source.find("void fragment(){"))+"void fragment(){ALBEDO=vec3(.2,.1,0.0);ALPHA=.25;}"
 var material=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
 var samples=[];var failures=[]
 for background in [Color.BLACK,Color.WHITE]:
  environment.background_color=background
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  var image=viewport.get_texture().get_image();var actual=image.get_pixel(64,64).srgb_to_linear();var expected=Color(.2,.1,0)+background*.75
  var error=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
  samples.append({"background":[background.r,background.g,background.b],"linear_actual":[actual.r,actual.g,actual.b],"linear_expected":[expected.r,expected.g,expected.b],"maximum_error":error})
  if error>.025:failures.append("Premultiplied blend mismatch "+str(error))
 var report={"failures":failures,"samples":samples,"scope":"Actual Godot sight shader vertex/render_mode with constant fragment radiance (.2,.1,0), alpha .25 over black/white, linear tonemap; checks ONE + ONE_MINUS_SRC_ALPHA without multiplying radiance by alpha. 8bit sRGB readback tolerance .025."}
 var file=FileAccess.open("res://evidence/sight-blending-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
