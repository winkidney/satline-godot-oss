extends SceneTree
class ControlledQuality extends "res://scripts/render_quality.gd":
 var milliseconds=50.0
 var samples_per_frame=1
 func frame(game:Node,_measured_ms:float=-1)->void:
  for i in samples_per_frame:super.frame(game,milliseconds)
var game
var frame=0
var previous=""
var snapshots=[]
var auto_events=[]
var failures=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false;game.player.invulnerable=true;game.game_ui.save_path="";game.game_ui.settings.quality="auto"
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.render_quality=ControlledQuality.new();game.render_quality.dynamic.state.enabled=true;game.render_quality.apply(game,"ultra")
 game.render_quality.quality_auto.connect(func(name):auto_events.append({"frame":frame,"quality":name}))
 game.game_flow.pause()
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==351:game.render_quality.milliseconds=10;game.render_quality.samples_per_frame=20
 game._game_tick(1.0/60,{});game._process(1.0/60)
 var quality=game.render_quality;var state=quality.dynamic.state;var marker="%s/%.1f"%[quality.current,state.scale]
 if marker!=previous:
  previous=marker;call_deferred("inspect",frame,quality.current,state.scale)
 if frame==710:
  if quality.current!="low" or state.scale!=1.0:failures.append("floor degradation / scale recovery")
  if auto_events.size()!=3:failures.append("quality:auto count")
  if game.game_ui.settings.quality!="auto" or game.game_ui.effective_quality!="low":failures.append("auto changed persisted preference or effective UI")
  game.game_flow.resume()
 if frame==720:finishing=true;call_deferred("finish")
 return false
func inspect(requested:int,name:String,scale:float)->void:
 await process_frame;RenderingServer.force_draw(false)
 var pipeline=game.post_pipeline;var expected=game.render_quality.resolution(Vector2i(1280,720),game.render_quality.PRESETS[name],1,scale)
 if pipeline.world_port.size!=expected or pipeline.weapon_port.size!=expected:failures.append("dynamic viewport resize "+name+str(scale))
 if not pipeline.combined_depth.is_ready() or not pipeline.half_depth.is_ready():failures.append("dynamic depth readiness")
 snapshots.append({"frame":requested,"quality":name,"scale":scale,"size":[pipeline.world_port.size.x,pipeline.world_port.size.y],"shadow":game.sun_shadow_pass.viewport.size.x})
 if requested>1:game.get_viewport().get_texture().get_image().save_png("res://evidence/dynamic-%s-%.1f.png"%[name,scale])
func finish()->void:
 if game.game_flow.state!="playing":failures.append("resume after adaptation")
 var report={"frames":frame,"snapshots":snapshots,"auto_events":auto_events,"changes":game.render_quality.changes,"final_state":game.render_quality.dynamic.state,"failures":failures,"scope":"Actual Main render-stage controller consumption with deterministic 50ms inputs then batched 10ms recovery samples; quality:auto, render resizing, depth readiness, preference retention and resume. Synthetic timing, not hardware performance measurement or one timing per presented recovery frame."}
 FileAccess.open("res://evidence/dynamic-resolution-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
