extends SceneTree
var game
var frame=0
var failures=[]
var samples=[]
var finishing=false
var rifle_shots=0
var movement_start=Vector3.ZERO
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false;game.game_ui.save_path=""
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.player.reset({"pos":Vector3(-32,0,6),"yaw":0},game.camera);game.player.invulnerable=true;game.game_ui.settings.sens=3;game.game_ui.settings.invertY=true
func key(code:int,pressed:bool,logical:int=0)->void:
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code if logical==0 else logical;event.pressed=pressed;Input.parse_input_event(event)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==5:key(KEY_RIGHT,true);key(KEY_L,true)
 if frame==35:key(KEY_RIGHT,false)
 if frame==39:key(KEY_L,false)
 if frame==40:key(KEY_DOWN,true);key(KEY_K,true)
 if frame==60:key(KEY_DOWN,false);key(KEY_K,false)
 if frame==90:key(KEY_ENTER,true)
 if frame==120:key(KEY_ENTER,false);rifle_shots=game.weapon.shot_count
 if frame==140:key(KEY_KP_2,true,KEY_DOWN)
 if frame==141:key(KEY_KP_2,false,KEY_DOWN)
 if frame==180:key(KEY_KP_ENTER,true)
 if frame==210:key(KEY_KP_ENTER,false)
 if frame==230:key(KEY_KP_1,true)
 if frame==231:key(KEY_KP_1,false)
 if frame==272:movement_start=game.player.pos;key(KEY_W,true,KEY_Z)
 if frame==282:key(KEY_W,false,KEY_Z)
 if frame==292:key(KEY_W,true)
 if frame==295:
  game.source_mouse_input.dx=.25;game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  if not game.source_keyboard_input.held.is_empty() or game.source_mouse_input.dx!=0:failures.append("focus-out did not clear input")
 if frame==297:key(KEY_W,false)
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame in [34,38,60,120,170,210,270]:
  samples.append({"frame":frame,"yaw":game.player.yaw,"pitch":game.player.pitch,"weapon":game.weapon.current,"shots":game.weapon.shot_count})
 if frame==38 and absf(game.player.yaw+1.05)>1e-10:failures.append("turn aliases / alias release behavior")
 if frame==60 and absf(game.player.pitch+.42)>1e-10:failures.append("keyboard vertical rate / ignores mouse inversion")
 if frame==120 and rifle_shots<=0:failures.append("Enter did not fire")
 if frame==170 and game.weapon.current!="pistol":failures.append("physical numpad2 did not select pistol")
 if frame==210 and game.weapon.shot_count<=rifle_shots:failures.append("numpad Enter did not fire")
 if frame==270 and game.weapon.current!="rifle":failures.append("numpad1 did not select rifle")
 if frame==290 and game.player.pos.distance_to(movement_start)<=.05:failures.append("physical W under logical Z did not move")
 if frame==300:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/keyboard-runtime.png")
 var report={"frames":frame,"samples":samples,"failures":failures,"scope":"Actual Godot key events through Main: arrow/IJKL alias-rate/release behavior, mouse sensitivity/invert independence, Enter fire, physical numpad2 under logical Down, numpad Enter and numpad1, physical W under logical Z, focus-out notification clears held/look. Controlled native events; no physical hardware/layout/GUI focus acceptance."}
 FileAccess.open("res://evidence/keyboard-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
