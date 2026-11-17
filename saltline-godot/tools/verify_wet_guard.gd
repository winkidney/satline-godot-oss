extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/wet-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_wet_guard_probe.gdshader",{},true);target.viewport.transparent_bg=true;var failures=[];var reports=[];var total=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  target.material.set_shader_parameter("uMacro",Vector4(sample.macro[0],sample.macro[1],sample.macro[2],sample.macro[3]));target.material.set_shader_parameter("uParams",Vector4(sample.params[0],sample.params[1],sample.params[2],sample.params[3]));target.material.set_shader_parameter("uTri",sample.tri);target.material.set_shader_parameter("uTint",sample.tint);target.material.set_shader_parameter("uRain",sample.rain);target.material.set_shader_parameter("uIndoor",sample.indoor);await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>.001 and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Experimental guarded hash plus production wet preparation vs original mk SL_FX block,48 position/orientation/rain/triplanar/tint profiles. Explicit footprint substitutes fwidth in original for controlled tests; output wet/up/bead/sample red, RGBA16F absolute.001. Does not cover final tint, roughness, actual derivatives or complete material image."};var file=FileAccess.open("res://evidence/wet-surface-guard-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
