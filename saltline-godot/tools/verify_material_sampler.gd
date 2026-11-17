extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var source_rows=not "--prepared-rows" in OS.get_cmdline_user_args();var gpu="--reference-gpu" in OS.get_cmdline_user_args();var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/material-sampler-reference-gpu.json" if gpu else "res://assets/export/fixtures/material-sampler-reference.json"));var viewport=SubViewport.new();viewport.size=Vector2i(32,32);viewport.use_hdr_2d=true;viewport.transparent_bg=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,0,3);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.current=true
 var instance=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(2,2);instance.mesh=quad;viewport.add_child(instance);var scene=SaltlineSourceScene.new();root.add_child(scene)
 var image=Image.create_from_data(2,2,false,Image.FORMAT_RGBA8,PackedByteArray([0,0,255,255,255,255,255,255,255,0,0,255,0,255,0,255]));if source_rows:image.flip_y()
 scene.source_row_textures.probe=ImageTexture.create_from_image(image)
 var reports=[];var failures=[]
 for i in reference.cases.size():
  var sample=reference.cases[i];scene.texture_records.probe={"wrapS":1001 if sample.clamp else 1000,"wrapT":1001 if sample.clamp else 1000,"minFilter":1006,"repeat":[1,1],"offset":[0,0]}
  var material=scene._material({"type":"MeshBasicMaterial","name":"sampler-probe","props":{"color":[1,1,1],"map":{"$texture":"probe"}},"userData":{}});if source_rows:
   var shader=Shader.new();shader.code=material.shader.code.replace("vec2(uv.x,1.0-uv.y)","uv");material.shader=shader
  material.set_shader_parameter("uv_repeat",Vector2.ZERO);material.set_shader_parameter("uv_offset",Vector2(sample.uv[0],sample.uv[1]));instance.material_override=material
  for warm in 3:await RenderingServer.frame_post_draw
  var actual=viewport.get_texture().get_image().get_pixel(16,16);var maximum=0.0
  for channel in 3:maximum=maxf(maximum,absf(actual[channel]-sample.pixels[channel]))
  reports.append({"case":i,"maximum_error":maximum,"actual":[actual.r,actual.g,actual.b]})
  if maximum>.002:failures.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"failures":failures,"source_rows":source_rows,"gpu_reference":gpu,"scope":"Actual generic MeshBasic material factory and spatial sampler vs originalThree,48 linear-filter RGBA8 primary-color texels wrap/clamp UV cases,absolute.002. No mip/anisotropic or arbitrarySRGB gradients proof."};FileAccess.open("res://evidence/material-sampler-gpu-source-rows-verification.json" if gpu and source_rows else "res://evidence/material-sampler-gpu-verification.json" if gpu else "res://evidence/material-sampler-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));viewport.queue_free();scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
