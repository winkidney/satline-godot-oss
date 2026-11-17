extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/finish-gpu-reference.json"))
 var image=Image.create_from_data(data.width,data.height,false,Image.FORMAT_RGBA8,PackedByteArray(data.input));image.flip_y();var texture=ImageTexture.create_from_image(image)
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var pass_data=pipeline._filter(Vector2i(data.width,data.height),"res://shaders/source_finish.gdshader",{"tSrc":texture,"uTexel":Vector2(1.0/data.width,1.0/data.height)},false)
 for frame in 3:await process_frame
 var baseline=[];var failures=[];var reports=[]
 for index in data.cases.size():
  var sample=data.cases[index]
  for key in sample.values:pass_data.material.set_shader_parameter(key,sample.values[key])
  await RenderingServer.frame_post_draw
  var output=pass_data.viewport.get_texture().get_image();var maximum=0.0;var absolute=0.0;var bias=0.0;var over_one=0;var errors=[]
  for y in int(data.height):
   for x in int(data.width):
    var actual=output.get_pixel(x,int(data.height)-1-y)
    for channel in 3:
     var expected=float(sample.color[(y*int(data.width)+x)*4+channel]);
     if index==3:baseline.append(actual[channel]*255)
     var signed_error=actual[channel]*255-expected;var error=absf(signed_error);maximum=maxf(maximum,error);absolute+=error;bias+=signed_error;errors.append(error)
     if error>1.01:over_one+=1
  errors.sort();var count=errors.size();var mean=absolute/count
  if index<4 and maximum>1.01:failures.append({"case":index,"maximum_byte_error":maximum,"over_one":over_one})
  var noise_stats={}
  if index>=4:
   var native_energy=0.0;var reference_energy=0.0;var native_mean=0.0;var reference_mean=0.0;var native_max=0.0;var reference_max=0.0;var n=0
   for y in int(data.height):
    for x in int(data.width):
     var actual=output.get_pixel(x,int(data.height)-1-y)
     for channel in 3:
      var offset=(y*int(data.width)+x)*3+channel;var rgba=(y*int(data.width)+x)*4+channel
      var native_delta=actual[channel]*255-baseline[offset];var reference_delta=float(sample.color[rgba])-float(data.cases[3].color[rgba])
      native_energy+=native_delta*native_delta;reference_energy+=reference_delta*reference_delta;native_mean+=native_delta;reference_mean+=reference_delta;native_max=maxf(native_max,absf(native_delta));reference_max=maxf(reference_max,absf(reference_delta));n+=1
   var bound=ceili(float(sample.values.uGrain)*255+float(sample.values.uDither))+1
   if native_max>bound+.01:failures.append({"case":index,"noise_amplitude":native_max,"source_bound":bound})
   noise_stats={"native_rms_bytes":sqrt(native_energy/n),"reference_rms_bytes":sqrt(reference_energy/n),"native_mean_bytes":native_mean/n,"reference_mean_bytes":reference_mean/n,"native_max_bytes":native_max,"reference_max_bytes":reference_max,"analytical_bound_bytes":bound}
  reports.append({"noise":noise_stats,"case":index,"parameters":sample.values,"maximum_byte_error":maximum,"mean_absolute_byte_error":mean,"bias_bytes":bias/count,"p95_byte_error":errors[int(count*.95)],"channels_over_one_byte":over_one})
  if index==7:output.save_png("res://evidence/finish-native.png")
 var report={"failures":failures,"cases":reports,"scope":"Actual original Three nk RGBA8 vs native2D RGBA8 at64x32. Cases0..3 suppress grain+dither to isolate FXAA/sharpen; threshold1 byte. Cases4..7 report original stochastic hash terms separately; native noise amplitude checked against source grain/dither analytical range plus quantization. Statistics and pixel errors retained, no cross-driver stochastic pixel-equivalence claim."}
 var file=FileAccess.open("res://evidence/finish-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
