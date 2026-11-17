extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var size=Vector2i(256,64);var image=Image.create(size.x,size.y,false,Image.FORMAT_RGBAF);var depth=Image.create(size.x,size.y,false,Image.FORMAT_RF)
 for y in size.y:
  for x in size.x:
   var value=4.0 if x%2==0 else .125
   image.set_pixel(x,y,Color(value,.25,.5,1));depth.set_pixel(x,y,Color(.02 if x<32 else .8,0,0,1))
 var first=pipeline._filter(size,"res://shaders/source_motion.gdshader",{"tColor":ImageTexture.create_from_image(image),"tDepth":ImageTexture.create_from_image(depth),"uInvViewProj":Projection.IDENTITY,"uPrevViewProj":Projection.IDENTITY,"uShutter":.5,"uRes":Vector2(size)},true)
 var failures=[];var reports=[]
 for mode in ["stationary","subpixel","behind","moving"]:
  var previous=Projection.IDENTITY
  if mode=="subpixel":previous.w.x=.0001
  if mode=="behind":previous.w.w=-1.0
  if mode=="moving":previous.w.x=.2
  first.material.set_shader_parameter("uPrevViewProj",previous)
  await RenderingServer.frame_post_draw
  var actual=first.viewport.get_texture().get_image();var changed=0;var weapon_error=0.0;var world_error=0.0;var green_error=0.0;var moving_max=0.0;var moving_min=4.0
  for y in size.y:
   for x in size.x:
    var p=actual.get_pixel(x,y);var expected=image.get_pixel(x,y);var error=absf(p.r-expected.r)
    green_error=maxf(green_error,absf(p.g-.25))
    if x<32:weapon_error=maxf(weapon_error,error)
    else:
     world_error=maxf(world_error,error)
     if error>.01:changed+=1
     if x>40 and x<240:moving_max=maxf(moving_max,p.r);moving_min=minf(moving_min,p.r)
  if weapon_error>.002:failures.append(mode+": weapon changed")
  if green_error>.002:failures.append(mode+": constant channel changed")
  if mode!="moving" and world_error>.002:failures.append(mode+": bypass changed")
  if mode=="moving" and (changed<1000 or moving_max>=3.9 or moving_min<=.2):failures.append("no meaningful motion blur")
  reports.append({"mode":mode,"weapon_error":weapon_error,"world_error":world_error,"changed_samples":changed,"interior_minimum":moving_min,"interior_maximum":moving_max,"constant_channel_error":green_error})
  if mode=="moving":actual.save_png("res://evidence/motion-kernel-native.png")
 var report={"cases":reports,"failures":failures,"scope":"Native GPU semantic checks only: stationary/subpixel/behind-camera bypass, weapon .02 depth bypass, moving high-contrast stripe blur and constant channels. Not originalThree numerical parity or game integration."}
 var file=FileAccess.open("res://evidence/motion-kernel-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
