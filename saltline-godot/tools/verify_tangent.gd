extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/tangent-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_tangent_probe.gdshader",{},true);var failures=[];var reports=[];var total=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  target.material.set_shader_parameter("uScale",Vector2(sample.scale[0],sample.scale[1]));target.material.set_shader_parameter("uFace",sample.face);target.material.set_shader_parameter("uMap",Vector3(sample.map[0],sample.map[1],sample.map[2]));await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>.001 and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Original Three getTangentFrame with real derivatives and DOUBLE_SIDED correction vs production derivative helper,32 mirrored/zeroUV/face/map cases,absolute.001. Synthetic planar eye coordinates; actual spatial mesh interpolation remains separate."};var file=FileAccess.open("res://evidence/tangent-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
