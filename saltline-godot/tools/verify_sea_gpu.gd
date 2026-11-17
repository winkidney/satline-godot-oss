extends SceneTree
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sea-wave-reference.json"));var failures=[];var max_error=0.0
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera=Camera3D.new();camera.position.z=2;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;viewport.add_child(camera);camera.current=true
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=environment
 var source=FileAccess.get_file_as_string("res://shaders/sea.gdshader");var code=source.left(source.find("void fragment(){"))
 code=code.replace("render_mode diffuse_lambert,specular_schlick_ggx;","render_mode unshaded,cull_disabled;")
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform vec3 probe_world;varying vec3 probe_disp;")
 code=code.replace("vSAmp = ","swp=probe_world;vSAmp = ")
 code=code.replace("  vGWorld = swp;","  vGWorld = swp;probe_disp=sdisp*vSAmp;")
 code+="void fragment(){ALBEDO=probe_disp*2.0+vec3(.5);}"
 var shader=Shader.new();shader.code=code;var material=ShaderMaterial.new();material.shader=shader
 var quad=QuadMesh.new();quad.size=Vector2.ONE;var mesh=MeshInstance3D.new();mesh.mesh=quad;mesh.material_override=material;viewport.add_child(mesh)
 var samples=[]
 for index in reference.cases.size():
  var row=reference.cases[index];material.set_shader_parameter("probe_world",vec(row.world));material.set_shader_parameter("uTime",row.time)
  for frame in 2:await process_frame
  await RenderingServer.frame_post_draw
  var color=viewport.get_texture().get_image().get_pixel(32,32).srgb_to_linear();var actual=Vector3(color.r-.5,color.g-.5,color.b-.5)*.5
  var expected=vec(row.displacement);var error=(actual-expected).abs().max_axis_index();var delta=(actual-expected).abs()[error];max_error=maxf(max_error,delta)
  if delta>.004:failures.append(index)
  samples.append({"case":index,"actual":[actual.x,actual.y,actual.z],"expected":row.displacement,"maximum_error":delta})
 var report={"cases":reference.cases.size(),"failures":failures,"maximum_error_m":max_error,"samples":samples,"scope":"Actual native sea vertex shader via GPU varying readback with controlled world coordinates; original CP-generated GLSL rounded waves as reference. 8bit sRGB encode/decode tolerance .004m; not full surface lighting parity."}
 var file=FileAccess.open("res://evidence/sea-wave-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"cases":report.cases,"failures":failures,"maximum_error_m":max_error}));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
