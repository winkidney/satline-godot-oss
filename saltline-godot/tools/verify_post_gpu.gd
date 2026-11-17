extends SceneTree
func _initialize()->void:call_deferred("run")
func texture(value:Array)->ImageTexture:
 var image=Image.create(1,1,false,Image.FORMAT_RGBAF);image.fill(Color(value[0],value[1],value[2],1));return ImageTexture.create_from_image(image)
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/post-gpu-reference.json"));var source=FileAccess.get_file_as_string("res://shaders/source_composite.gdshader")
 var shader=Shader.new();shader.code=source.replace("shader_type canvas_item;","shader_type canvas_item;\nuniform vec2 probe_uv;").replace("source_composite(vec2(UV.x,1.0-UV.y))","source_composite(probe_uv)")
 var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("uSunCol",Vector3(1,.72,.42));material.set_shader_parameter("uSunUv",Vector2(.72,.61))
 var viewport=SubViewport.new();viewport.size=Vector2i(16,16);viewport.use_hdr_2d=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var rect=ColorRect.new();rect.size=Vector2(16,16);rect.material=material;viewport.add_child(rect)
 var failures=[];var maximum=0.0;var samples=[]
 for index in reference.cases.size():
  var row=reference.cases[index]
  for key in row.values:material.set_shader_parameter(key,row.values[key])
  for key in row.textures:material.set_shader_parameter(key,texture(row.textures[key]))
  material.set_shader_parameter("probe_uv",Vector2(row.uv[0],row.uv[1]))
  for frame in 2:await process_frame
  await RenderingServer.frame_post_draw
  var color=viewport.get_texture().get_image().get_pixel(8,8);var actual=[color.r,color.g,color.b];var error=0.0
  for channel in 3:
   var delta=absf(actual[channel]-row.color[channel]);maximum=maxf(maximum,delta);error=maxf(error,delta)
   if delta>.002:failures.append("%d %d"%[index,channel])
  if absf(color.a-1)>.001:failures.append("display alpha")
  samples.append({"case":index,"actual":actual,"expected":row.color,"maximum_error":error})
 var report={"cases":reference.cases.size(),"channels":reference.cases.size()*3,"failures":failures,"maximum_error":maximum,"samples":samples,"scope":"Actual original tk/ao/sv Three r180 Float32 GPU target vs Godot RGBA16F numeric readback of source compositor output. Constant HDR inputs, varied UV/exposure/auto formula/health/ADS/flare/bloom inputs; display alpha1. Spatial CA and image down kernels separate."}
 var file=FileAccess.open("res://evidence/post-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"cases":report.cases,"failures":failures,"maximum_error":maximum}));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
