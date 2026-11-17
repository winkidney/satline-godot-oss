extends SceneTree
var game
var frame=0
var failures=[]
var snapshots=[]
var transitions=[]
var resize_shutter=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false;game.player.invulnerable=true;game.game_ui.save_path=""
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==30:game.game_flow.pause();game.game_ui.open_panel()
 if frame in [45,120,195,270]:
  var name={45:"low",120:"medium",195:"ultra",270:"high"}[frame]
  for choice in game.game_ui.choices:
   if choice.key=="quality" and choice.value==name:choice.button.pressed.emit();break
 if frame==340:game.game_ui._select("quality","medium")
 if frame==350:root.size=Vector2i(960,540)
 if frame==410:root.size=Vector2i(1280,720);game.game_ui._select("quality","high")
 if frame==435:
  root.size=Vector2i(1200,800);root.emit_signal("size_changed")
  if game.post_pipeline.motion_has_history:failures.append("resize retained motion history")
 if frame==450:root.size=Vector2i(1280,720)
 if frame==455:
  for name in ["low","ultra","low","high"]:game.game_ui._select("quality",name)
 if frame==335:game.game_ui.close_panel();game.game_flow.resume()
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame in [45,195,410,455]:
  var shadow=game.sun_shadow_pass
  var ready=game.source_sun_service.ready
  var bound_ready=true;var bound_count=0
  for reference in game.source_sun_service.bound_materials.values():
   var material=reference.get_ref()
   if material!=null:
    bound_count+=1
    if not material.get_shader_parameter("source_sun_ready") or material.get_shader_parameter("source_sun_shadow_size")!=Vector2(shadow.viewport.size):bound_ready=false
  var trace={"frame":frame,"shadow_tick":shadow.frame-1,"shadow_size":shadow.viewport.size.x,"mode":shadow.viewport.render_target_update_mode,"pending":shadow.force_pending,"warm":shadow.resize_pending,"sun_ready":ready,"bound_ready":bound_ready,"bound_count":bound_count}
  transitions.append(trace)
  if bound_count==0 or not ready or not bound_ready or shadow.force_pending or shadow.viewport.render_target_update_mode!=SubViewport.UPDATE_ONCE:failures.append("first-frame shadow plan "+str(frame))
  call_deferred("inspect_shadow",frame)
 if frame in [435,445]:
  var shutter=float(game.post_pipeline.motion_material.get_shader_parameter("uShutter"));resize_shutter.append({"frame":frame,"shutter":shutter})
  if frame==435 and shutter!=0:failures.append("resize first shutter not zero")
  if frame==445 and shutter<=0:failures.append("resize shutter did not resume")
 if frame in [90,165,240,315,395]:call_deferred("inspect",frame)
 if frame==460:finishing=true;call_deferred("finish")
 return false
func inspect_shadow(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 if not game.sun_shadow_pass.depth.is_ready_for(game.sun_shadow_pass.viewport.size):failures.append("new shadow not rendered "+str(requested))
func inspect(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 var quality=game.render_quality.current;var preset=game.render_quality.PRESETS[quality];var pipeline=game.post_pipeline
 var expected=game.render_quality.resolution(Vector2i(game.get_viewport().size),preset)
 var row={"frame":requested,"quality":quality,"world_size":[pipeline.world_port.size.x,pipeline.world_port.size.y],"world_samples":pipeline.world_samples.samples,"weapon_samples":pipeline.weapon_samples.samples,"shadow_size":game.sun_shadow_pass.viewport.size.x,"ao":pipeline.ao_enabled,"motion":pipeline.motion_enabled,"reflection":game.planar_reflection.report.duplicate(true),"depth_ready":pipeline.combined_depth.is_ready(),"half_ready":pipeline.half_depth.is_ready()}
 if pipeline.world_port.size!=expected:failures.append("resolution "+quality)
 if pipeline.world_samples.samples!=maxi(1,int(preset.msaa)) or pipeline.weapon_samples.samples!=maxi(1,int(preset.msaa)):failures.append("MSAA "+quality)
 if row.shadow_size!=preset.shadow or pipeline.ao_enabled!=preset.ao or pipeline.motion_enabled!=preset.motionBlur:failures.append("quality controls "+quality)
 if not row.depth_ready or not row.half_ready:failures.append("depth not ready "+quality)
 if quality=="low" and row.reflection.get("active",false):failures.append("low reflection still active")
 if quality!="low" and not row.reflection.get("active",false):failures.append("reflection not active "+quality)
 var taps=8 if quality=="low" else 16 if quality=="ultra" else 12
 if not pipeline.ao_materials[0].shader.code.contains("i < %d"%taps):failures.append("AO shader taps "+quality)
 if not pipeline.volume_materials[0].shader.code.contains("i < %d"%int(preset.volSteps)):failures.append("volume shader steps "+quality)
 if pipeline.weapon_port.size!=pipeline.world_port.size:failures.append("weapon resize "+quality)
 var pixels=2*tan(deg_to_rad(game.camera.fov)*.5)/pipeline.world_port.size.y
 if game.game_flow.state=="playing" and absf(game.rain_system.pixel_width-pixels)>1e-10:failures.append("rain pixel width "+quality)
 row.window_size=[root.size.x,root.size.y];row.hud_size=[game.get_viewport().get_visible_rect().size.x,game.get_viewport().get_visible_rect().size.y];row.state=game.game_flow.state;row.ao_taps=taps;row.volume_steps=preset.volSteps;row.rain_pixel_width=game.rain_system.pixel_width
 snapshots.append(row);game.get_viewport().get_texture().get_image().save_png("res://evidence/quality-%s.png"%quality)
func finish()->void:
 if game.game_flow.state!="playing":failures.append("resume failed")
 var report={"frames":frame,"snapshots":snapshots,"transitions":transitions,"resize_shutter":resize_shutter,"failures":failures,"scope":"Actual settings button signals across low/medium/ultra/high, native render size, depth readiness/MSAA samples, shadow size, AO/motion flags, planar gate, resume. No source pixel/performance/DRS/boot asset quality parity."}
 FileAccess.open("res://evidence/quality-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
