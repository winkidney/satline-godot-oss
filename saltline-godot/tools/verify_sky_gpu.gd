extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sky-gpu-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var record:Dictionary={}
 for item in data.materials:
  if item.name=="saltline-sky":record=item
 var source=FileAccess.get_file_as_string("res://shaders/dynamic_sky.gdshader");var code=source.left(source.find("void vertex(){"))
 code=code.replace("cull_front","cull_disabled").replace("shader_type spatial;","shader_type spatial;\nuniform vec3 probe_direction;")
 code+="void vertex(){vDir=probe_direction;POSITION=vec4(VERTEX.xy,1.0,1.0);}"
 var shader=Shader.new();shader.code=code;var material=ShaderMaterial.new();material.shader=shader
 for key in record.uniforms:
  var value=record.uniforms[key].value
  if key=="tNoise":
   for item in data.textures:
    if item.id==value["$texture"]:
     var image=Image.create_from_data(item.width,item.height,false,Image.FORMAT_RGBA8,FileAccess.get_file_as_bytes("res://assets/export/"+item.file))
     material.set_shader_parameter(key,ImageTexture.create_from_image(image))
  else:material.set_shader_parameter(key,Vector3(value[0],value[1],value[2]) if value is Array else value)
 var viewport=SubViewport.new();viewport.size=Vector2i(16,16);viewport.use_hdr_2d=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera=Camera3D.new();camera.position.z=2;viewport.add_child(camera);camera.current=true
 var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
 var quad=QuadMesh.new();quad.size=Vector2(2,2);var mesh=MeshInstance3D.new();mesh.mesh=quad;mesh.material_override=material;viewport.add_child(mesh)
 var failures=[];var samples=[];var maximum=0.0;var max_relative=0.0;var format=-1
 for index in reference.cases.size():
  var row=reference.cases[index];material.set_shader_parameter("probe_direction",Vector3(row.direction[0],row.direction[1],row.direction[2]));material.set_shader_parameter("uTime",row.time);material.set_shader_parameter("uEnv",row.env);material.set_shader_parameter("uFlash",row.flash)
  for frame in 2:await process_frame
  await RenderingServer.frame_post_draw
  var image=viewport.get_texture().get_image();format=image.get_format();var color=image.get_pixel(8,8);var actual=[color.r,color.g,color.b];var error=0.0
  for channel in 3:
   var delta=absf(actual[channel]-row.color[channel]);maximum=maxf(maximum,delta);error=maxf(error,delta);max_relative=maxf(max_relative,delta/maxf(.1,row.color[channel]))
   if delta>maxf(.004,absf(row.color[channel])*.002):failures.append("%d %d"%[index,channel])
  samples.append({"case":index,"actual":actual,"expected":row.color,"maximum_error":error})
 var report={"cases":reference.cases.size(),"channels":reference.cases.size()*3,"failures":failures,"maximum_absolute_error":maximum,"maximum_relative_error_over_floor_0_1":max_relative,"image_format":format,"samples":samples,"scope":"Actual original Three r180 sky fragment shader Float32 GPU readback vs native Godot HDR RGBA16F GPU readback, controlled direction/time/env/flash, original noise texture. Tolerance max(.004, .2 percent radiance); excludes camera cube geometry and final tone/post pipeline."}
 var file=FileAccess.open("res://evidence/sky-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"cases":report.cases,"failures":failures,"maximum_absolute_error":maximum,"maximum_relative_error":max_relative,"image_format":format}));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
