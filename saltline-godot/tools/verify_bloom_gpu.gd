extends SceneTree
var ports=[]
var references=[]
var labels=[]
func _initialize()->void:call_deferred("run")
func record(pass_data:Dictionary,expected:Dictionary,label:String)->Texture2D:
 ports.append(pass_data.viewport);references.append(expected);labels.append(label);return pass_data.viewport.get_texture()
func run()->void:
 var path="res://assets/export/fixtures/bloom-gpu-reference.json"
 if not FileAccess.file_exists(path):printerr("Missing original GPU fixture");quit(2);return
 var data=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not data.has("width") or not data.has("down"):printerr("GPU fixture is metadata, not pixel reference");quit(2);return
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var image=Image.create_from_data(data.width,data.height,false,Image.FORMAT_RGBAF,PackedFloat32Array(data.input).to_byte_array());image.flip_y()
 var previous:Texture2D=ImageTexture.create_from_image(image);var size=Vector2i(data.width,data.height);var down=[]
 for index in 6:
  var expected=data.down[index];var pass_data=pipeline._filter(Vector2i(expected.width,expected.height),"res://shaders/source_downsample.gdshader",{"tSrc":previous,"uTexel":Vector2.ONE/Vector2(size),"uFirst":1.0 if index==0 else 0.0})
  previous=record(pass_data,expected,"down%d"%index);down.append(previous);size=pass_data.viewport.size
 for index in range(4,-1,-1):
  var expected=data.up[index];var pass_data=pipeline._filter(Vector2i(expected.width,expected.height),"res://shaders/source_upsample.gdshader",{"tLow":previous,"tHigh":down[index],"uTexel":Vector2.ONE/Vector2(size),"uMix":.62})
  previous=record(pass_data,expected,"up%d"%index);size=pass_data.viewport.size
 var adapt=Image.create(1,1,false,Image.FORMAT_RGBAF);adapt.fill(Color(.12,0,0,1));var texture=ImageTexture.create_from_image(adapt);previous=down[2]
 for index in 2:
  var expected=data.streak[index];size=Vector2i(expected.width,expected.height)
  var pass_data=pipeline._filter(size,"res://shaders/source_streak.gdshader",{"tSrc":previous,"tAdapt":texture,"uDir":Vector2(1.5 if index==0 else 5.0,0)/size.x,"uThreshold":2.2 if index==0 else 0.0,"uExposure":1.0,"uKey":.12,"uMinE":.6,"uMaxE":2.0,"uAuto":0.0})
  previous=record(pass_data,expected,"streak%d"%index)
 var dirt_reference=data.get("dirt",{})
 var dirt_texture=pipeline.load_source_dirt()
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var failures=[];var maximum=0.0;var comparisons=0;var levels=[]
 for index in ports.size():
  var expected=references[index];var output=ports[index].get_texture().get_image();var level_max=0.0;var count=0
  for y in int(expected.height):
   for x in int(expected.width):
    var actual=output.get_pixel(x,int(expected.height)-1-y)
    for channel in 3:
     var target=float(expected.color[(y*int(expected.width)+x)*4+channel]);var error=absf(actual[channel]-target);maximum=maxf(maximum,error);level_max=maxf(level_max,error);comparisons+=1
     if error>maxf(.004,absf(target)*.006):
      count+=1
      if failures.size()<20:failures.append({"pass":labels[index],"x":x,"y":y,"channel":channel,"actual":actual[channel],"expected":target,"error":error})
  levels.append({"pass":labels[index],"maximum_error":level_max,"failures":count})
 var dirt_errors=[];var dirt_maximum=0.0
 if dirt_texture!=null:
  var dirt_image=dirt_texture.get_image();dirt_image.save_png("res://evidence/dirt-native.png")
  for sample in dirt_reference.samples:
   var actual=dirt_image.get_pixel(sample.x,287-int(sample.y))
   for channel in 3:
    var error=absf(actual[channel]*255-float(sample.color[channel]));dirt_maximum=maxf(dirt_maximum,error)
    if error>.01 and dirt_errors.size()<20:dirt_errors.append({"x":sample.x,"y":sample.y,"channel":channel,"actual":actual[channel]*255,"expected":sample.color[channel]})
  if not dirt_errors.is_empty():failures.append("dirt mismatch")
 var report={"dirt_samples":dirt_reference.get("samples",[]).size(),"dirt_maximum_byte_error":dirt_maximum,"dirt_errors":dirt_errors,"levels":levels,"channels":comparisons,"failures":failures,"maximum_error":maximum,"scope":"Actual original Three Float32 j9/K9/J9 vs native HDR RGBA16F, six down/five up/two streak; nonuniform64x32 HDR gradient and radiance300 point. Tolerance max(.004,.6percent radiance) permits accumulated half-float quantization. Static dirt compared separately against original RGBA8 at 1504 sampled pixels, source-baked texture byte tolerance0.01. Procedural GPU residual retained in dirt-procedural-diagnostic.json."}
 var file=FileAccess.open("res://evidence/bloom-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
