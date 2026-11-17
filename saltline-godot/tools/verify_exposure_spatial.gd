extends SceneTree
func _initialize()->void:call_deferred("run")
func texture(values:Array,width:int,height:int)->Texture2D:
 var image=Image.create_from_data(width,height,false,Image.FORMAT_RGBAF,PackedFloat32Array(values).to_byte_array());image.flip_y();return ImageTexture.create_from_image(image)
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/exposure-gpu-reference.json"))
 if not reference.has("spatial"):printerr("Missing spatial GPU reference");quit(2);return
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var pass_data=pipeline._filter(Vector2i(2,2),"res://shaders/source_adapt.gdshader",{});var shader=pass_data.material;var failures=[];var samples=[];var maximum=[0.0,0.0]
 for index in reference.spatial.size():
  var sample=reference.spatial[index]
  var lum=texture(sample.input,sample.width,sample.height);var depth=texture(sample.depthInput,sample.depthWidth,sample.depthHeight);var previous=texture(sample.previous,1,1)
  for pair in [["tLum",lum],["tDepth",depth],["tPrev",previous],["uRate",sample.rate],["uVisRate",sample.visRate],["uSunUv",Vector2(sample.sunUv[0],sample.sunUv[1])],["uSunOn",sample.sunOn],["uAspect",sample.aspect]]:shader.set_shader_parameter(pair[0],pair[1])
  await RenderingServer.frame_post_draw
  var actual=pass_data.viewport.get_texture().get_image().get_pixel(0,0);var errors=[]
  for channel in 2:
   var expected=float(sample.color[channel]);var error=absf(actual[channel]-expected);maximum[channel]=maxf(maximum[channel],error);errors.append(error)
   if error>maxf(.000002,expected*.0011):failures.append({"case":index,"channel":channel,"actual":actual[channel],"original":expected,"error":error})
  samples.append({"case":index,"native":[actual.r,actual.g],"original":sample.color,"errors":errors})
 var report={"cases":reference.spatial.size(),"channels":reference.spatial.size()*2,"failures":failures,"maximum_error":maximum,"samples":samples,"scope":"Actual original Three HalfFloat Q9 vs native2x2 HDR GPU, nonuniform20x12 luminance: half bright, centre bright, corner bright, stripes and coloured distributions; original35-point weighting and log mean. Synthetic128x64 nearest depth covers split occluder, 0.99999 threshold, chess pattern, offscreen sun disk samples, varied aspect/previous/visibility rate. Does not prove real scene depth bridge or camera sun projection."}
 var file=FileAccess.open("res://evidence/exposure-spatial-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"cases":report.cases,"failures":failures,"maximum_error":maximum}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
