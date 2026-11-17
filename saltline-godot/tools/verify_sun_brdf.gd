extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-brdf-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var pass_data=pipeline._filter(Vector2i(2,2),"res://shaders/source_sun_brdf_probe.gdshader",{},true);var reports=[];var failures=[];var channels=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.values:pass_data.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var v=sample.vectors[key];pass_data.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  await RenderingServer.frame_post_draw
  var image=pass_data.viewport.get_texture().get_image();var maxima=[0.0,0.0]
  for x in 2:
   var pixel=image.get_pixel(x,0)
   for channel in 4:
    channels+=1;var expected=float(sample.pixels[x*4+channel]);var error=absf(pixel[channel]-expected);maxima[x]=maxf(maxima[x],error)
    if error>maxf(.002,absf(expected)*.003) and failures.size()<20:failures.append({"case":i,"term":x,"channel":channel,"actual":pixel[channel],"expected":expected,"error":error})
  reports.append({"case":i,"maximum_errors":maxima})
 var report={"cases":reports,"channels":channels,"failures":failures,"scope":"Original Three Standard direct Lambert/GGX vs native same extracted functions, 96inputs, diffuse/specular separatelyRGBA16F, metallic0/.35/1,roughfloor/grazing/geometryroughscalar,wetF0.075,visibility1/.6/0. Tolerance max(.002,.3percent). No PCSS or true perfragment geometry derivative proof."};var file=FileAccess.open("res://evidence/sun-brdf-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
