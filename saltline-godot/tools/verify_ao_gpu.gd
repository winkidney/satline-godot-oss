extends SceneTree
var world=Texture2DRD.new()
var weapon=Texture2DRD.new()
var sources=[]
func _initialize()->void:call_deferred("run")
func _set_sources(width:int,height:int,world_bytes:PackedByteArray,weapon_bytes:PackedByteArray)->void:
 var rd=RenderingServer.get_rendering_device();var format=RDTextureFormat.new();format.width=width;format.height=height;format.format=RenderingDevice.DATA_FORMAT_R32_SFLOAT;format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
 var a=rd.texture_create(format,RDTextureView.new(),[world_bytes]);var b=rd.texture_create(format,RDTextureView.new(),[weapon_bytes]);world.texture_rd_rid=a;weapon.texture_rd_rid=b;sources.append(a);sources.append(b)
func _free_sources()->void:
 world.texture_rd_rid=RID();weapon.texture_rd_rid=RID();var rd=RenderingServer.get_rendering_device()
 for resource in sources:rd.free_rid(resource)
 sources.clear()
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/ao-gpu-reference.json"))
 if reference==null or not reference.has("cases") or reference.cases.is_empty() or not reference.cases[0].has("composite"):
  printerr("Missing original AO composite fixture; regenerate reference first");quit(2);return
 var owner=Node3D.new();root.add_child(owner);var viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport);var camera=Camera3D.new();viewport.add_child(camera);camera.current=true
 var bridge=SaltlineHalfDepthBridge.new();bridge.world_source=world;bridge.weapon_source=weapon;var compositor=Compositor.new();compositor.compositor_effects=[bridge];camera.compositor=compositor
 var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var passes=[];var composite_pass={};var isolated_pass={};var failures=[];var reports=[]
 for index in reference.cases.size():
  var sample=reference.cases[index];var half_size=Vector2i(sample.halfSize[0],sample.halfSize[1]);viewport.size=Vector2i(sample.width,sample.height)
  var world_image=Image.create_from_data(sample.width,sample.height,false,Image.FORMAT_RF,PackedFloat32Array(sample.world).to_byte_array());world_image.flip_y();var weapon_image=Image.create_from_data(sample.width,sample.height,false,Image.FORMAT_RF,PackedFloat32Array(sample.weapon).to_byte_array());weapon_image.flip_y()
  RenderingServer.call_on_render_thread(_set_sources.bind(sample.width,sample.height,world_image.get_data(),weapon_image.get_data()));bridge.prepare_size(half_size);bridge.near_plane=sample.near;bridge.far_plane=sample.far
  if passes.is_empty():
   var tan_half=tan(deg_to_rad(74.0)*.5)
   passes.append(pipeline._filter(half_size,"res://shaders/source_ao.gdshader",{"tDepthHalf":bridge.output,"uTanHalf":Vector2(16.0/9*tan_half,tan_half),"uRadius":.9,"uIntensity":1.6,"uAspect":16.0/9},false))
   for axis in 2:passes.append(pipeline._filter(half_size,"res://shaders/source_ao_blur.gdshader",{"tDepthHalf":bridge.output,"tSrc":passes[axis].viewport.get_texture()},false))
  for pass_data in passes:pass_data.viewport.size=half_size;pass_data.material.set_shader_parameter("uResolution",Vector2(half_size))
  passes[0].material.set_shader_parameter("uTexel",Vector2.ONE/Vector2(half_size));passes[1].material.set_shader_parameter("uDir",Vector2(1.0/half_size.x,0));passes[2].material.set_shader_parameter("uDir",Vector2(0,1.0/half_size.y))
  var color_image=Image.create_from_data(sample.width,sample.height,false,Image.FORMAT_RGBAF,PackedFloat32Array(sample.colorInput).to_byte_array());color_image.flip_y();var depth_image=Image.create_from_data(sample.width,sample.height,false,Image.FORMAT_RGBAF,PackedFloat32Array(sample.fullDepth).to_byte_array());depth_image.flip_y()
  var previous=Image.create(1,1,false,Image.FORMAT_RGBAF);previous.fill(Color(.12,0,0,1));var volume=Image.create(1,1,false,Image.FORMAT_RGBAF);volume.fill(Color(0,0,0,1))
  if composite_pass.is_empty():composite_pass=pipeline._filter(Vector2i(sample.width,sample.height),"res://shaders/source_ao_composite.gdshader",{},true)
  composite_pass.viewport.size=Vector2i(sample.width,sample.height)
  for key in sample.compositeUniforms:composite_pass.material.set_shader_parameter(key,sample.compositeUniforms[key])
  for pair in [["tColor",ImageTexture.create_from_image(color_image)],["tDepth",ImageTexture.create_from_image(depth_image)],["tDepthHalf",bridge.output],["tAO",passes[2].viewport.get_texture()],["tVol",ImageTexture.create_from_image(volume)],["tAdapt",ImageTexture.create_from_image(previous)],["uHalfRes",Vector2(half_size)]]:composite_pass.material.set_shader_parameter(pair[0],pair[1])
  if isolated_pass.is_empty():isolated_pass=pipeline._filter(Vector2i(sample.width,sample.height),"res://shaders/source_ao_composite.gdshader",{},true)
  isolated_pass.viewport.size=Vector2i(sample.width,sample.height)
  for key in sample.compositeUniforms:isolated_pass.material.set_shader_parameter(key,sample.compositeUniforms[key])
  var exact_half=Image.create_from_data(half_size.x,half_size.y,false,Image.FORMAT_RGBAF,PackedFloat32Array(sample.depth).to_byte_array());exact_half.flip_y();var exact_ao=Image.create_from_data(half_size.x,half_size.y,false,Image.FORMAT_RGBA8,PackedByteArray(sample.blurY));exact_ao.flip_y()
  for pair in [["tColor",ImageTexture.create_from_image(color_image)],["tDepth",ImageTexture.create_from_image(depth_image)],["tDepthHalf",ImageTexture.create_from_image(exact_half)],["tAO",ImageTexture.create_from_image(exact_ao)],["tVol",ImageTexture.create_from_image(volume)],["tAdapt",ImageTexture.create_from_image(previous)],["uHalfRes",Vector2(half_size)]]:isolated_pass.material.set_shader_parameter(pair[0],pair[1])
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  var depth=bridge.output.get_image();var depth_max=0.0;var byte_max=[0.0,0.0,0.0];var images=[]
  for pass_data in passes:images.append(pass_data.viewport.get_texture().get_image())
  for y in half_size.y:
   for x in half_size.x:
    var expected=float(sample.depth[(y*half_size.x+x)*4]);var actual=depth.get_pixel(x,half_size.y-1-y).r;var error=absf(actual-expected);depth_max=maxf(depth_max,error)
    if error>maxf(.00001,expected*.00002) and failures.size()<20:failures.append({"case":index,"kind":"depth","x":x,"y":y,"actual":actual,"original":expected})
    for stage in 3:
     var key=["ao","blurX","blurY"][stage];var expected_byte=float(sample[key][(y*half_size.x+x)*4]);var actual_byte=images[stage].get_pixel(x,half_size.y-1-y).r*255;var byte_error=absf(actual_byte-expected_byte);byte_max[stage]=maxf(byte_max[stage],byte_error)
     if byte_error>1.01 and failures.size()<20:failures.append({"case":index,"kind":key,"x":x,"y":y,"actual":actual_byte,"original":expected_byte})
  var composite=composite_pass.viewport.get_texture().get_image();var composite_max=0.0;var isolated=isolated_pass.viewport.get_texture().get_image();var isolated_max=0.0
  for y in int(sample.height):
   for x in int(sample.width):
    var pixel=composite.get_pixel(x,int(sample.height)-1-y)
    var exact_pixel=isolated.get_pixel(x,int(sample.height)-1-y)
    for channel in 3:
     var expected=float(sample.composite[(y*int(sample.width)+x)*4+channel]);var error=absf(pixel[channel]-expected);composite_max=maxf(composite_max,error)
     var isolated_error=absf(exact_pixel[channel]-expected);isolated_max=maxf(isolated_max,isolated_error)
     if isolated_error>maxf(.002,absf(expected)*.003) and failures.size()<20:failures.append({"case":index,"kind":"isolated-composite","x":x,"y":y,"channel":channel,"error":error})
  reports.append({"composite_maximum_error":composite_max,"isolated_composite_maximum_error":isolated_max,"case":index,"size":[sample.width,sample.height],"half_size":[half_size.x,half_size.y],"depth_maximum_error":depth_max,"byte_maximum_error":byte_max,"ready":bridge.is_ready()})
  if index==1:images[0].save_png("res://evidence/ao-kernel-native.png");images[2].save_png("res://evidence/ao-blur-native.png")
 var report={"cases":reports,"failures":failures,"scope":"Actual originalq9 Float32 target vs nativeR32F compute depthhalf, even/odd exact texel selection and world<.05/weapon sentinel; originalAO12 and each7tap bilateral blur RGBA8/nearest vs native2D. Depth tolerance max1e-5/2e-5relative, AO/blur1byte permits separate8bit quantization. Includes original joint-bilateral full scene composite Float32 vs nativeRGBA16F, original lit attenuation/exposure/bypass. Composite gated with identical originalDepthHalf/AO8 inputs at max.002/.3percent; whole nativechain residual recorded separately because precedingRGBA8 pass can differ1byte. Controlled noMSAA inputs, not fullscene or MSAA4 equivalence."}
 var file=FileAccess.open("res://evidence/ao-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));camera.compositor=null
 for pass_data in passes:pass_data.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 composite_pass.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;isolated_pass.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 bridge.dispose();RenderingServer.call_on_render_thread(_free_sources)
 for frame in 3:await process_frame
 owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
