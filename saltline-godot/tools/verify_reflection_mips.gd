extends SceneTree
const Capture=preload("res://scripts/reflection_hdr_bridge.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/reflection-mip-reference.json"))
 RenderingServer.call_on_render_thread(gpu.bind(reference))
func gpu(reference:Dictionary)->void:
 var capture=Capture.new();capture.allow_test_upload=true;var failures=[];var reports=[];var channels=0
 if not capture._initialize_gpu():call_deferred("finish",{"failures":["compute initialization"]});return
 for sample in reference.cases:
  var size=Vector2i(sample.width,sample.height);capture._ensure_output(size)
  var base=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBAF,PackedFloat32Array(sample.levels[0].pixels).to_byte_array());base.flip_y();base.convert(Image.FORMAT_RGBAH);var bytes=base.get_data();var full_size=0
  for level in sample.levels:full_size+=int(level.width)*int(level.height)*8
  bytes.resize(full_size);capture._rd.texture_update(capture._target,0,bytes);capture._generate_mips();var actual=capture._rd.texture_get_data(capture._target,0);var offset=0;var maxima=[]
  for level in sample.levels:
   var count=int(level.width)*int(level.height)*8;var image=Image.create_from_data(level.width,level.height,false,Image.FORMAT_RGBAH,actual.slice(offset,offset+count));offset+=count;var maximum=0.0
   for y in int(level.height):
    for x in int(level.width):
     var pixel=image.get_pixel(x,int(level.height)-1-y)
     for channel in 4:
      channels+=1;var expected=float(level.pixels[(y*int(level.width)+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
      if error>.002 and failures.size()<20:failures.append({"base":[size.x,size.y],"level":level.level,"x":x,"y":y,"channel":channel,"actual":pixel[channel],"expected":expected,"error":error})
   maxima.append({"level":level.level,"size":[level.width,level.height],"maximum_error":maximum})
  reports.append({"size":[size.x,size.y],"levels":maxima})
 capture._release_gpu();call_deferred("finish",{"cases":reports,"channels":channels,"failures":failures,"scope":"Actual originalThree RGBA16F automatic WebGL mip chain vs native GPU compute center-mapped bilinear with explicit halfRNE eachlevel. Four aligned nonsquare bases including sourcehigh640x360 with odd intermediate dimensions, allRGBA channels. Test uploads originalbase viaCPU and reads output for verification only; production builds aftercompositorcopy onGPU. Absolute tolerance.002."})
func finish(report:Dictionary)->void:
 var file=FileAccess.open("res://evidence/reflection-mip-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if report.failures.is_empty() else 1)
