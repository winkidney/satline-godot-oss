extends SceneTree
var game
var frame=0
var drip
var falls=0
var ripples=0
var splashes=0
var moved=false
var moved_frame=0
var capture_frame=-1
var random_stream
var failures=[]
var samples=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.player.reset({"pos":Vector3(-20,0,-.5),"yaw":0},game.camera);game.player.pitch=-.25;game._game_tick(0,{})
 var seeded=preload("res://scripts/source_rng.gd").new(4207);var tape=[]
 for i in 4096:tape.append(seeded.randf())
 random_stream=preload("res://scripts/fx_random.gd").new(tape)
 game.explosion_effects.rng=random_stream;game.impact_effects.rng=random_stream;game.impact_effects.pool.rng=random_stream;game.impact_effects.lit_pool.rng=random_stream
 var position=game.camera.global_position-game.camera.global_basis.z*2.8-game.camera.global_basis.x*.4
 drip=game.explosion_effects.add_emitter([position.x,2.6,position.z],"drip",{"ttl":4.5})
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if not moved and frame>50 and drip.drop>.2:
  game.explosion_effects.set_emitter_position(drip,[drip.position64[0]+.6,2.6,drip.position64[2]]);moved=true;moved_frame=frame
 game._advance_effects(1.0/60);game._process(1.0/60)
 for particle in game.impact_effects.pool.particles:
  if particle.age!=0:continue
  if particle.mode==2 and particle.frame==4:
   ripples+=1
   if absf(particle.position.y-.014)>.000001:failures.append("ripple height")
   samples.append({"frame":frame,"kind":"ripple","x":particle.position.x,"z":particle.position.z})
   if ripples==1:capture_frame=frame+10
  elif particle.mode==1 and particle.frame==6:
   if absf(particle.life-.35)<.000001:splashes+=1
   else:falls+=1
 if frame==capture_frame:call_deferred("capture")
 if frame==360:finishing=true;call_deferred("finish")
 return false
func capture()->void:
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/drip-ripple.png")
func finish()->void:
 if not moved or falls<3 or ripples<2 or splashes!=ripples*3:failures.append("drop generation / three-splash sequence")
 if drip.active:failures.append("drip TTL")
 if samples.size()>0 and absf(samples[0].x-drip.position.x)>.000003:failures.append("in-flight moved target ripple")
 var report={"frames":frame,"seed":4207,"draws":random_stream.calls,"falls":falls,"ripples":ripples,"splashes":splashes,"moved_frame":moved_frame,"samples":samples,"failures":failures,"scope":"Actual Main FX/render paths, public double-position drip, in-flight setPos, ring height, three splashes and TTL. Controlled seeded FX tape, physics/AI frozen; no source browser trajectory/pixel or production entropy/performance proof."}
 FileAccess.open("res://evidence/drip-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game.explosion_effects.clear();game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
