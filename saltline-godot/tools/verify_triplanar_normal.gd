extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/triplanar-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_triplanar_probe.gdshader",{},true);var failures=[];var reports=[];var total=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  target.material.set_shader_parameter("uScale",Vector2(sample.scale[0],sample.scale[1]));target.material.set_shader_parameter("uFace",sample.face);await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>.001 and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Original vk GPU vs production sourceTriNormal function,48 negative-axis/restnormal/strength/face/nonorthogonal-axis profiles,RGBA16F encodednormal, absolute.001. Source samples texture centers; native supplies identical decodedtexture values. No skin palette or UV footprint equivalence proof."};var file=FileAccess.open("res://evidence/triplanar-normal-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
