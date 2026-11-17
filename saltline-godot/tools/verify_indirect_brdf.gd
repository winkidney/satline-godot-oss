extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/indirect-brdf-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,1),"res://shaders/source_indirect_probe.gdshader",{},true);var failures=[];var reports=[];var total=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.values:target.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 1:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>maxf(.001,absf(expected)*.0015) and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Original Three indirect DFG/multiscattering/diffuse/specular/AO kernels vs production functions;96 cases768channels,absolute.001 or relative.0015. Explicit radiance/irradiance inputs,no livePMREM or materialintegration."};var file=FileAccess.open("res://evidence/indirect-brdf-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
