extends SceneTree
var game
var frame=0
var failures=[]
var observed=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 var relay=game.mission.relays[0]
 game.player.reset({"pos":relay.o.pos+Vector3(0,0,1.3),"yaw":0},game.camera);game.player.invulnerable=true
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame in [45,300]:
  var event=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=frame==45;Input.parse_input_event(event)
 game._game_tick(1.0/60,{"move":Vector2.ZERO,"fire":false});game._process(1.0/60)
 var prompt=game.game_ui.status_hud.interaction
 if frame in [30,100,180,330]:
  observed.append({"frame":frame,"active":prompt.active,"alpha":prompt.alpha,"progress":prompt.progress,"dash_offset":prompt.dash_offset,"cut":game.mission.run.cut})
  call_deferred("capture",frame)
 if frame==30 and (not prompt.active or prompt.alpha<.99):failures.append("relay proximity did not show prompt")
 if frame==100 and (prompt.progress<=0 or prompt.progress>=1):failures.append("holding did not advance ring")
 if frame==330 and (game.mission.run.cut!=1 or prompt.active or prompt.alpha!=0):failures.append("completed relay did not clear prompt")
 if frame==360:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/interaction-%03d.png"%requested)
func finish()->void:
 var report={"frames":frame,"observed":observed,"failures":failures,"scope":"Actual Main player at relay A, proximity prompt, held interaction progress, actual relay completion and prompt fade. Controlled starting pose; not navigation/gamepad/touch/pixel parity."}
 FileAccess.open("res://evidence/interaction-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
