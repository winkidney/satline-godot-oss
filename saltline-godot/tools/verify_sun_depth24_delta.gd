extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 root.disable_3d=true;ProjectSettings.set_setting("rendering/saltline/source_depth_24",false);var owner=Node3D.new();root.add_child(owner);var source=SaltlineSourceScene.new();owner.add_child(source);source.load_source()
 for warm in 3:await process_frame;RenderingServer.force_draw(false)
 var arrays=[];var reports=[];var failures=[]
 for enabled in [false,true]:
  ProjectSettings.set_setting("rendering/saltline/source_depth_24",enabled);var shadow=SaltlineSunShadowPass.new();shadow.setup(owner,source,4096);var monitor=load("res://tools/depth_format_monitor.gd").new();var effects=shadow.camera.compositor.compositor_effects;effects.append(monitor);shadow.camera.compositor.compositor_effects=effects
  for warm in 8:shadow.update();await process_frame;RenderingServer.force_draw(false)
  var image=shadow.depth.output.get_image();arrays.append(image.get_data().to_float32_array());var format=monitor.snapshot();var expected=RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT if enabled else RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT
  if format.format!=expected or shadow.report.eligible!=148 or not shadow.report.unsupported.is_empty():failures.append("shadow pass attachment/caster mismatch")
  reports.append({"source_depth_24":enabled,"format":format,"casters":shadow.report.duplicate(true)});shadow.dispose();shadow=null
  for warm in 3:await process_frame;RenderingServer.force_draw(false)
 var maximum=0.0;var changed=0;var covered=0;var outside_bound=0
 if arrays[0].size()!=4096*4096 or arrays[1].size()!=4096*4096:failures.append("shadow map dimensions")
 for index in mini(arrays[0].size(),arrays[1].size()):
  var a=float(arrays[0][index]);var b=float(arrays[1][index]);var delta=absf(a-b);maximum=maxf(maximum,delta)
  if delta>0.0:changed+=1
  if a<.99999:covered+=1
  if not is_finite(a) or not is_finite(b) or delta>2.0/16777216.0:outside_bound+=1
 if outside_bound>0:failures.append("D24 change exceeds two q24 bound")
 var report={"passes":reports,"pixels":arrays[0].size(),"covered_pixels":covered,"changed_pixels":changed,"maximum_depth_difference":maximum,"outside_two_q24":outside_bound,"failures":failures,"scope":"Actual fixed source148casters full4096R32F shadow producer D32vsD24 acrossall16M pixels,stationary same source skeletons. Twoq24 quantization bound only;not originalGL packedshadow wholemap equivalence or dynamicPCSS thresholds."};FileAccess.open("res://evidence/sun-depth24-delta-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
