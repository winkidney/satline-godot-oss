extends SceneTree
func _initialize()->void:call_deferred("run")
func matrix(a:Array)->Projection:return Projection(Vector4(a[0],a[1],a[2],a[3]),Vector4(a[4],a[5],a[6],a[7]),Vector4(a[8],a[9],a[10],a[11]),Vector4(a[12],a[13],a[14],a[15]))
func texture(values:Array,width:int,height:int)->Texture2D:
 var image=Image.create_from_data(width,height,false,Image.FORMAT_RGBAF,PackedFloat32Array(values).to_byte_array());image.flip_y();return ImageTexture.create_from_image(image)
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/volume-gpu-reference.json"))
 if reference==null or not reference.has("cases"):printerr("Missing original volume GPU fixture");quit(2);return
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var size=Vector2i(reference.width,reference.height);var depth=texture(reference.depth,size.x,size.y);var shadow=texture(reference.shadow,reference.shadowSize,reference.shadowSize)
 var first=pipeline._filter(size,"res://shaders/source_volume.gdshader",{"tDepthHalf":depth,"tShadow":shadow,"uShadowMatrix":matrix(reference.shadowMatrix),"uResolution":Vector2(size)},true);first.viewport.transparent_bg=true;var passes=[first]
 for axis in 2:
  var blur=pipeline._filter(size,"res://shaders/source_volume_blur.gdshader",{"tDepthHalf":depth,"tSrc":passes[axis].viewport.get_texture(),"uDir":Vector2(1.0/size.x,0) if axis==0 else Vector2(0,1.0/size.y)},true);blur.viewport.transparent_bg=true;passes.append(blur)
 var failures=[];var reports=[];var total=0
 for index in reference.cases.size():
  var sample=reference.cases[index]
  for key in sample.values:first.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var v=sample.vectors[key];first.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  first.material.set_shader_parameter("uCamWorld",matrix(sample.camWorld));first.material.set_shader_parameter("uTanHalf",Vector2(sample.tanHalf[0],sample.tanHalf[1]))
  await RenderingServer.frame_post_draw
  var maxima=[0.0,0.0,0.0];var alpha_range=[1.0,0.0]
  for stage in 3:
   var image=passes[stage].viewport.get_texture().get_image();var key=["volume","blurX","blurY"][stage]
   for y in size.y:
    for x in size.x:
     var actual=image.get_pixel(x,size.y-1-y);alpha_range[0]=minf(alpha_range[0],actual.a);alpha_range[1]=maxf(alpha_range[1],actual.a)
     for channel in 4:
      total+=1;var expected=float(sample[key][(y*size.x+x)*4+channel]);var error=absf(actual[channel]-expected);maxima[stage]=maxf(maxima[stage],error)
      if error>maxf(.002,absf(expected)*.003) and failures.size()<30:failures.append({"case":index,"stage":stage,"x":x,"y":y,"channel":channel,"native":actual[channel],"original":expected,"error":error})
  reports.append({"case":index,"shadow":sample.values.uHasShadow,"maximum_error":maxima,"alpha_range":alpha_range})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"OriginalY9 high24steps/QM bilateral BLUR_TOL.30 eachRGBA16F vs nativeHDR2D RGBA16F explicitRNE storage,16cases shadowoff/on8cameras, sentinel/surface/sky/far continuation/warehouse density. IncludesRGBA transmittancealpha. ReferencepackedRGBA8 shadow decoded toR32 numeric input for native, no real4096scene or jointcomposite proof. Tolerance max.002/.3percent."};var file=FileAccess.open("res://evidence/volume-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
