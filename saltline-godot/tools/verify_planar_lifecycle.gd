extends SceneTree
const Reflection=preload("res://scripts/planar_reflection.gd")
const Trace=preload("res://scripts/render_order_trace.gd")
const Marker=preload("res://scripts/render_order_marker.gd")
func _initialize()->void:call_deferred("run")
func mark(camera:Camera3D,trace,label:String)->void:
 var marker=Marker.new();marker.trace=trace;marker.label=label;var effects=camera.compositor.compositor_effects;effects.append(marker);camera.compositor.compositor_effects=effects
func run()->void:
 var original=XRServer.primary_interface;var original_count=XRServer.get_interface_count();var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main.set_process(false)
 if not main.planar_reflection.initialized:printerr("Reflection not initialized");quit(2);return
 var trace=Trace.new();mark(main.planar_reflection.camera,trace,"reflection");mark(main.sun_shadow_pass.camera,trace,"sun");mark(main.camera,trace,"world");mark(main.view_camera,trace,"weapon")
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
 var cases=[{"name":"baseline","size":Vector2i(1280,720),"height":1.4,"enabled":true},{"name":"odd_resize","size":Vector2i(961,541),"height":1.4,"enabled":true},{"name":"below_plane","size":Vector2i(961,541),"height":.02,"enabled":true},{"name":"height_recover","size":Vector2i(961,541),"height":1.4,"enabled":true},{"name":"disabled","size":Vector2i(961,541),"height":1.4,"enabled":false},{"name":"enabled","size":Vector2i(961,541),"height":1.4,"enabled":true},{"name":"minimum","size":Vector2i(128,64),"height":1.4,"enabled":true},{"name":"full_restore","size":Vector2i(1280,720),"height":1.4,"enabled":true}]
 var failures=[];var reports=[];var frame=0
 for sample in cases:
  root.size=sample.size;main.planar_reflection.enabled=sample.enabled
  for warm in 8:
   frame+=1;trace.begin(frame);main.camera.global_position=Vector3(-25,sample.height,6);main.camera.look_at(Vector3(0,-.1,-8),Vector3.UP);main._process(0.0);await RenderingServer.frame_post_draw
  var pass_data=main.planar_reflection;var active=sample.enabled and sample.height>=.03;var image_size=pass_data.capture.output.get_size();var expected=Vector2i(maxi(64,int(floor(sample.size.x*.5/16+.5))*16),maxi(32,int(floor(sample.size.y*.5/8+.5))*8));var gain=float(pass_data.ground.get_shader_parameter("uReflOn"));var order=trace.snapshot()
  if root.size!=sample.size:failures.append(sample.name+": actual logical resize did not occur")
  if active:
   if image_size!=Vector2(expected) or pass_data.viewport.size!=expected or not pass_data.capture.is_ready():failures.append(sample.name+": reflection size/ready")
   if gain!=1.0:failures.append(sample.name+": active gain")
   if order.events.find("reflection")<0 or order.events.find("reflection")>order.events.find("world"):failures.append(sample.name+": reflection after world")
  else:
   if gain!=0.0 or pass_data.viewport.render_target_update_mode!=SubViewport.UPDATE_DISABLED or "reflection" in order.events:failures.append(sample.name+": inactive pass still renders")
  if main.post_pipeline.world_port.size!=sample.size or main.view_port.size!=sample.size:failures.append(sample.name+": world/weapon resize")
  reports.append({"case":sample.name,"logical_size":[root.size.x,root.size.y],"reflection_size":[image_size.x,image_size.y],"gain":gain,"ready":pass_data.capture.is_ready(),"order":order})
 # Dispose/reinstall without replacing the original sun pass or main world viewports.
 var old=main.planar_reflection;old.dispose();await process_frame
 if XRServer.primary_interface!=original or XRServer.get_interface_count()!=original_count:failures.append("XR state not restored after dispose")
 for item in ["apron","sea","rain","rainSplash"]:
  for record in main.source_scene.source.nodes:
   if record.name==item:
    var node=main.source_scene.source_nodes[record.id]
    if (node.layers&1)==0 or (node.layers&4)!=0:failures.append("world layers not restored "+item)
 main.planar_reflection=Reflection.new();main.planar_reflection.setup(main,main.source_scene,main.camera);main.planar_reflection.order_before_sun(main.sun_shadow_pass.viewport);mark(main.planar_reflection.camera,trace,"reflection")
 for warm in 9:
  frame+=1;trace.begin(frame);main._process(0.0);await RenderingServer.frame_post_draw
 var order=trace.snapshot();var reentered=main.planar_reflection.capture.is_ready() and main.planar_reflection.ground.get_shader_parameter("uReflOn")==1.0
 if not reentered or order.events!=["reflection","sun","world","weapon"]:failures.append("reentry readiness/order")
 var report={"engine":Engine.get_version_info(),"cases":reports,"reentry":{"ready":reentered,"order":order},"failures":failures,"scope":"Actual original scene complete graph, real logical1280x720→961x541→128x64→restore, original halfsize rounding, height .02 stop/recover, explicit disable/re-enable, XR registry and layer restore, reentry and sourceproducer callback order. No pertexel shadow-age or memory/performance proof."};var file=FileAccess.open("res://evidence/planar-lifecycle-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));main._dispose_game();main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
