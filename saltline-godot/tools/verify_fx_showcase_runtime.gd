extends SceneTree
var game
var showcase
var frame=0
var failures=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 var seeded=preload("res://scripts/source_rng.gd").new(4207);var tape=[]
 for i in 32768:tape.append(seeded.randf())
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 game.impact_effects.rng=rng;game.impact_effects.pool.rng=rng;game.impact_effects.lit_pool.rng=rng;game.explosion_effects.rng=rng
 var objects=preload("res://scripts/fx_showcase_geometry.gd").isolate(game.source_scene,game.player.physics);game.source_scene.add_child(objects)
 if objects.get_child_count()!=4:failures.append("showcase objects")
 showcase=preload("res://scripts/fx_showcase.gd").new(game,"all")
 game.camera.position=Vector3(.3,1.6,7.2);game.camera.look_at(Vector3(.2,1,0));game.game_ui.hud.visible=false;game.view_camera.cull_mask=0;game.camera.make_current()
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1;showcase.update(1.0/60);game._advance_effects(1.0/60);game._process(1.0/60)
 game.camera.global_position=Vector3(.3,1.6,7.2);game.camera.look_at(Vector3(.2,1,0));game.game_ui.hud.visible=false;game.view_camera.cull_mask=0;game.camera.make_current()
 if frame==210:call_deferred("capture")
 if frame==360:finishing=true;call_deferred("finish")
 return false
func capture()->void:
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/fx-showcase-integration.png")
func finish()->void:
 if game.explosion_effects.count<1:failures.append("no explosion")
 if game.shells.emitted<20:failures.append("no shell stream")
 if game.impact_effects.impacts<30:failures.append("no impact stream")
 var report={"camera":[game.camera.global_position.x,game.camera.global_position.y,game.camera.global_position.z],"current_camera":str(game.post_pipeline.world_port.get_camera_3d().get_path()),"frames":frame,"impacts":game.impact_effects.impacts,"tracers":game.tracers.emitted,"shells":game.shells.emitted,"explosions":game.explosion_effects.count,"failures":failures,"scope":"Actual Main effects adapter on existing level, fixed60Hz, frozen AI; KP meshes, ground and collision isolated; native runtime screenshot, not source pixel parity."}
 FileAccess.open("res://evidence/fx-showcase-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game.explosion_effects.clear();game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
