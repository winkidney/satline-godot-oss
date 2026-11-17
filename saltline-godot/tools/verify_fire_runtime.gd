extends SceneTree
var game
var frame=0
var fire
var first_light
var initial_light_position:Vector3
var failures=[]
var samples=[]
var capturing=false
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.player.reset({"pos":Vector3(-20,0,-.5),"yaw":0},game.camera);game._game_tick(0,{})
 var position=game.camera.global_position-game.camera.global_basis.z*1.8-game.camera.global_basis.x*.55-Vector3(0,1.5,0)
 fire=game.explosion_effects.add_emitter(position,"fire",{"ttl":2.5,"scale":.85});first_light=fire.light
 if first_light==null:failures.append("fire light not acquired")
 else:initial_light_position=first_light.light.global_position
func _process(_dt:float)->bool:
 if game==null or finishing or capturing:return false
 frame+=1
 game._advance_effects(1.0/60);game._process(1.0/60)
 if frame in [60,120]:
  samples.append({"frame":frame,"intensity":first_light.source_intensity,"lit":game.impact_effects.lit_pool.emitted,"add":game.impact_effects.pool.emitted})
  if not first_light.busy or not first_light.persistent or first_light.source_intensity<=0:failures.append("persistent flicker light")
  var row=game.light_pool.slots.find(first_light);var packed=game.source_local_light_data.image.get_pixel(3,row).b
  if absf(packed-first_light.source_intensity)>.000003:failures.append("light shader data not updated")
 if frame==90:capturing=true;call_deferred("capture_pair")
 if frame==120:
  game.explosion_effects.set_emitter_position(fire,fire.position+game.camera.global_basis.x*.3)
  if first_light.light.global_position.distance_to(initial_light_position)>.000001:failures.append("source fixed light position changed")
 if frame==170:
  if fire.active or fire.light!=null or first_light.busy or first_light.persistent or first_light.source_intensity!=0:failures.append("TTL did not release light")
 if frame==180:
  fire=game.explosion_effects.add_emitter(game.camera.global_position-game.camera.global_basis.z*1.8-Vector3(0,1.5,0),"fire")
  if fire.light==null or game.light_pool.slots.find(fire.light)!=game.light_pool.slots.find(first_light):failures.append("released light not reused")
 if frame==210:
  game.explosion_effects.clear()
  if fire.active or fire.light!=null or first_light.busy or first_light.source_intensity!=0:failures.append("clear did not release light")
 if frame==240:finishing=true;call_deferred("finish")
 return false
func capture_pair()->void:
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/fire-light-on.png")
 var intensity=first_light.source_intensity;game.light_pool.set_energy(first_light,0);game._process(0)
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/fire-light-off.png")
 game.light_pool.set_energy(first_light,intensity);game._process(0);capturing=false
func finish()->void:
 var report={"frames":frame,"samples":samples,"failures":failures,"scope":"Actual Main production FX/render pipeline, fire particles and persistent light shader data; TTL/reuse/clear, original non-following light position. Paired on/off light captures hold FX simulation and world dt fixed. No source browser pixels, real performance or drip proof."}
 FileAccess.open("res://evidence/fire-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
