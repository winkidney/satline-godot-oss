extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var lum_image=Image.create(8,4,false,Image.FORMAT_RGBAF);lum_image.fill(Color(.1,.1,.1,1));var lum=ImageTexture.create_from_image(lum_image)
 var initial=Image.create(2,2,false,Image.FORMAT_RGBAF);initial.fill(Color(.12,0,0,1))
 var history=pipeline._filter(Vector2i(2,2),"res://shaders/source_history.gdshader",{"tHistory":ImageTexture.create_from_image(initial)})
 var depth=Image.create(2,2,false,Image.FORMAT_RF);depth.fill(Color(1,0,0,1))
 var adapt=pipeline._filter(Vector2i(2,2),"res://shaders/source_adapt.gdshader",{"tPrev":history.viewport.get_texture(),"tLum":lum,"tDepth":ImageTexture.create_from_image(depth),"uSunUv":Vector2(.5,.5),"uSunOn":0.0,"uRate":1.0,"uVisRate":1.0,"uAspect":16.0/9})
 history.material.set_shader_parameter("tHistory",adapt.viewport.get_texture())
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var previous=adapt.viewport.get_texture().get_image().get_pixel(0,0).r
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/exposure-gpu-reference.json"))
 var reference_maximum=0.0
 var failures=[];var samples=[];var maximum=0.0;var history_maximum=0.0;var drift_maximum=0.0;var continuous=previous
 for index in 180:
  var value=[.001,.01,.1,1.0,4.0,80.0][(index/30)%6]
  var dt=[1.0/60,1.0/30,.1][index%3];var fast=index%47==0;var rate=1.0 if index<2 else .6 if fast else 1.0-exp(-dt/1.5)
  lum_image.fill(Color(value,value,value,1));lum.update(lum_image);adapt.material.set_shader_parameter("uRate",rate)
  await RenderingServer.frame_post_draw
  var output=adapt.viewport.get_texture().get_image();var actual=output.get_pixel(0,0).r;var saved=history.viewport.get_texture().get_image().get_pixel(0,0).r
  var target=clampf(value,.002,40);var expected=lerpf(previous,target,rate);continuous=lerpf(continuous,target,rate)
  var reference_error=absf(actual-float(reference.samples[index].actual));reference_maximum=maxf(reference_maximum,reference_error)
  if reference_error>.0000001:failures.append({"frame":index,"original_gpu":reference.samples[index].actual,"native_gpu":actual})
  var error=absf(actual-expected);var history_error=absf(saved-previous);maximum=maxf(maximum,error);history_maximum=maxf(history_maximum,history_error);drift_maximum=maxf(drift_maximum,absf(actual-continuous))
  if error>maxf(.00003,absf(expected)*.0011) or history_error>.000001:failures.append({"frame":index,"actual":actual,"expected":expected,"history":saved,"previous":previous})
  for y in 2:
   for x in 2:
    if output.get_pixel(x,y).r!=actual:failures.append("Nonconstant2x2 adaptation")
  samples.append({"frame":index,"input":value,"dt":dt,"fast":fast,"rate":rate,"actual":actual,"expected":expected,"history":saved,"continuous_float":continuous});previous=actual
 var report={"original_half_float_maximum_error":reference_maximum,"frames":180,"failures":failures,"maximum_step_error":maximum,"maximum_history_error":history_maximum,"maximum_float32_history_drift":drift_maximum,"samples":samples,"scope":"Actual GPU Q9 and 2x2 history-copy feedback, constant luminance dark/bright/clamp transitions, variable dt and fast=.6; first two forced rate1. Tests same-frame update and exact previous-frame copy. No CPU readback in game; readback only in verifier. Original Three HalfFloat GPU temporal reference compared at1e-7. Does not prove spatial35-point metering or solar depth occlusion."}
 var file=FileAccess.open("res://evidence/exposure-history-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures,"maximum_step_error":maximum,"maximum_history_error":history_maximum,"maximum_drift":drift_maximum}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
