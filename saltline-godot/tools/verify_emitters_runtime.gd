extends SceneTree
var game
var frame=0
var steam
var embers
var stopped_add_count=0
var failures=[]
var samples=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.player.invulnerable=true
 game.player.reset({"pos":Vector3(-20,0,-.5),"yaw":0},game.camera);game._game_tick(0,{})
 var base=game.camera.global_position-game.camera.global_basis.z*1.6-Vector3(0,.9,0);var right=game.camera.global_basis.x
 steam=game.explosion_effects.add_emitter(base-right*.65,"steam",{"ttl":3.5,"scale":1.2})
 embers=game.explosion_effects.add_emitter(base+right*.65,"embers",{"ttl":5,"scale":1.3})
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==120:game.explosion_effects.set_emitter_position(steam,steam.position-game.camera.global_basis.x*.3)
 if frame==180:game.explosion_effects.stop_emitter(embers);stopped_add_count=game.impact_effects.pool.emitted
 game._advance_effects(1.0/60);game._process(1.0/60)
 if frame in [60,120,180,240]:samples.append({"frame":frame,"active":game.explosion_effects.emitters.size(),"lit_emitted":game.impact_effects.lit_pool.emitted,"add_emitted":game.impact_effects.pool.emitted,"lit_live":game.impact_effects.lit_pool.particles.size(),"add_live":game.impact_effects.pool.particles.size()})
 if frame==120:
  if game.impact_effects.lit_pool.emitted<=0 or game.impact_effects.pool.emitted<=0:failures.append("emitter paths not generating")
  call_deferred("capture")
 if frame==240:
  if steam.active or embers.active:failures.append("TTL / stop not applied")
  if game.impact_effects.pool.emitted!=stopped_add_count:failures.append("embers continued after stop")
 if frame==300:game.explosion_effects.clear();finishing=true;call_deferred("finish")
 return false
func capture()->void:
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/emitters-steam-embers.png")
func finish()->void:
 if not game.explosion_effects.emitters.is_empty():failures.append("clear emitters")
 var report={"frames":frame,"samples":samples,"failures":failures,"scope":"Actual Main FX _advance_effects and renderer with public steam/embers APIs, move, TTL, stop and clear. Gameplay physics/AI frozen, not a source whole-game timeline, exact pixels or fire/drip acceptance."}
 FileAccess.open("res://evidence/emitters-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
