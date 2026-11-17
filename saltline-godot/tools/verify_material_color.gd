extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/material-color-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_material_color_probe.gdshader",{},true);target.viewport.transparent_bg=true;var failures=[];var reports=[];var total=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in ["texel","vertex"]:
   var v=sample[key];target.material.set_shader_parameter("uTexel" if key=="texel" else "uVertex",Vector4(v[0],v[1],v[2],v[3]))
  target.material.set_shader_parameter("uTint",sample.tint);target.material.set_shader_parameter("uWet",sample.wet);await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>.001 and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Original mk tint and wet color followed by original color_fragment vs production helpers and vertex multiplication,48 RGBA/tint/wet cases, absolute.001. Does not cover texture filtering or full lighting."};var file=FileAccess.open("res://evidence/material-color-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
