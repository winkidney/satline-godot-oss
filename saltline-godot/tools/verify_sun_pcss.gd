extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-pcss-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var size=Vector2i(reference.width,reference.height);var shadow=Image.create_from_data(reference.shadowSize,reference.shadowSize,false,Image.FORMAT_RGBAF,PackedFloat32Array(reference.depth).to_byte_array());shadow.flip_y()
 var pass_data=pipeline._filter(size,"res://shaders/source_sun_pcss_probe.gdshader",{"tShadow":ImageTexture.create_from_image(shadow),"uShadowSize":Vector2(reference.shadowSize,reference.shadowSize),"uResolution":Vector2(size)},true);var failures=[];var reports=[];var channels=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.values:pass_data.material.set_shader_parameter(key,sample.values[key])
  for pair in [["uSlope",sample.slope],["uOffset",sample.offset],["uScale",sample.scale]]:pass_data.material.set_shader_parameter(pair[0],Vector2(pair[1][0],pair[1][1]))
  await RenderingServer.frame_post_draw
  var image=pass_data.viewport.get_texture().get_image();var maximum=0.0;var sum=0.0;var bad=0;var minimum=1.0;var maximum_visibility=0.0
  for y in size.y:
   for x in size.x:
    var pixel=image.get_pixel(x,size.y-1-y);minimum=minf(minimum,pixel.r);maximum_visibility=maxf(maximum_visibility,pixel.r)
    for channel in 4:
     channels+=1;var expected=float(sample.pixels[(y*size.x+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error);sum+=error
     if error>.002:
      bad+=1
      if failures.size()<20:failures.append({"case":i,"x":x,"y":y,"channel":channel,"actual":pixel[channel],"expected":expected,"error":error})
  reports.append({"case":i,"maximum_error":maximum,"mean_error":sum/(size.x*size.y*4),"failing_channels":bad,"minimum_visibility":minimum,"maximum_visibility":maximum_visibility})
 var report={"cases":reports,"channels":channels,"failures":failures,"scope":"Original jM high8search16filter GPU packedRGBA8 vs native scalarR32 equivalent input, actual receiver dFdx/dFdy and IGN screen direction,16cases edge/outside/slope/depth/radius/intensity. Absolute .002. No actual4096shadow geometry/vertex normalBias or default pipeline proof."};var file=FileAccess.open("res://evidence/sun-pcss-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
