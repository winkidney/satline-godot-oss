extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/backdrop-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(8,1),"res://shaders/source_backdrop_probe.gdshader",{},true);var reports=[];var failures=[]
 for index in reference.cases.size():
  var sample=reference.cases[index];target.material.set_shader_parameter("uTime",sample.time)
  for pair in [["position","uPosition"],["orbit","uOrbit"],["parameters","uParameters"],["blink","uBlink"]]:
   var v=sample[pair[0]];target.material.set_shader_parameter(pair[1],Vector4(v[0],v[1],v[2],v[3]) if v.size()==4 else Vector3(v[0],v[1],v[2]))
  await process_frame;RenderingServer.force_draw(false);var image=target.viewport.get_texture().get_image();var actuals=[];var maximum=0.0
  for channel in 4:
   var low=image.get_pixel(channel*2,0);var high=image.get_pixel(channel*2+1,0);var bytes=PackedByteArray([int(low.r),int(low.g),int(low.b),int(high.r)]);var actual=bytes.decode_float(0);var expected=float(sample.pixels[channel]);var error=absf(actual-expected);maximum=maxf(maximum,error);actuals.append(actual)
   if error>maxf(.00002,absf(expected)*.000001) and failures.size()<30:failures.append({"case":index,"channel":channel,"expected":expected,"actual":actual,"error":error})
  reports.append({"case":index,"maximum_error":maximum,"actual":actuals})
 var report={"cases":reports,"channels":reports.size()*4,"failures":failures,"scope":"Production backdrop helpers vs original96 vertex/attribute/time profiles,RGBA32F reference andfloat32 byte encoded native output;abs20micrometers orrel1e-6. Not raster/interpolation/culling proof."};FileAccess.open("res://evidence/backdrop-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":reports.size(),"failures":failures}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
