extends SceneTree
var game
var frame=0
var failures=[]
var samples=[]
var random_stream
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.player.reset({"pos":Vector3(-20,0,-.5),"yaw":0},game.camera);game._game_tick(0,{})
 game.impact_effects.lit_pool.clear()
 var seeded=preload("res://scripts/source_rng.gd").new(4207);var tape=[]
 for i in 4096:tape.append(seeded.randf())
 random_stream=preload("res://scripts/fx_random.gd").new(tape)
 game.impact_effects.rng=random_stream;game.impact_effects.lit_pool.rng=random_stream
 var p=game.camera.global_position-game.camera.global_basis.z*3
 for i in 3:
  game.impact_effects.smoke(p+game.camera.global_basis.x*(i-1)*1.1,{"count":4,"size":1.2,"life":2.5,"rise":.35,"color":["#526678","rgb(95,100,105)","hsl(25,20%,35%)"][i]})
 if game.impact_effects.lit_pool.particles.size()!=12:failures.append("initial smoke count")
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1;game._advance_effects(1.0/60);game._process(1.0/60)
 if frame in [1,30,90,210]:
  samples.append({"frame":frame,"particles":game.impact_effects.lit_pool.particles.size(),"quads":game.impact_effects.lit_pool.quads.size()})
  call_deferred("capture",frame)
 if frame==215:finishing=true;call_deferred("finish")
 return false
func capture(index:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 var image=root.get_texture().get_image()
 if image.is_empty():failures.append("empty viewport")
 image.save_png("res://evidence/smoke-runtime-%03d.png"%index)
func finish()->void:
 if game.impact_effects.lit_pool.particles.size()!=0:failures.append("smoke did not expire")
 if random_stream.calls!=144:failures.append("unexpected RNG draws: "+str(random_stream.calls))
 var report={"frames":frame,"draws":random_stream.calls,"samples":samples,"failures":failures,"scope":"Actual Main smoke/puff/lit pool/renderer, three source CSS colors, 12 puffs, seeded tape, fixed 60Hz, AI and gameplay frozen. Screenshots are native runtime evidence, not source pixel parity or measured realtime performance."}
 FileAccess.open("res://evidence/smoke-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
