extends SceneTree
var checks=0
var failures=[]
func expect(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label)
func clocks(game)->Array:return [game.mission.run.time,game.enemy_coordinator.time,game.weapon.time,game.rain_system.time]
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 expect(game.game_flow.state=="title","title remains title on focus loss")
 game.game_flow.start("mission",false,false,true)
 for i in 60:game._game_tick(1.0/60,{"move":Vector2.ZERO,"fire":false});game._process(1.0/60)
 expect(clocks(game).all(func(value):return value>.9),"all simulation clocks advance before focus loss")
 game.source_keyboard_input.key(KEY_W,true);game.source_mouse_buttons[MOUSE_BUTTON_LEFT]=true;game.jump_pending=true;game.weapon_actions.reload=true
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 expect(game.game_flow.state=="paused" and game.game_flow.menu=="paused","playing focus loss pauses")
 expect(not game.source_keyboard_input.down("forward") and game.source_mouse_buttons.is_empty(),"held movement/fire cleared")
 expect(not game.jump_pending and game.weapon_actions.is_empty() and not game.pause_pending,"queued actions cleared")
 var before=clocks(game)
 for i in 120:game._game_tick(1.0/60);game._process(1.0/60)
 expect(clocks(game)==before,"mission enemy weapon weather clocks frozen")
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
 expect(game.game_flow.state=="paused","regaining focus does not auto resume")
 await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/focus-pause.png")
 expect(game.game_ui.buttons.has("resume"),"real resume action exists")
 game.game_ui.buttons.resume.pressed.emit()
 expect(game.game_flow.state=="playing","real resume action restores gameplay")
 game._game_tick(1.0/60);game._process(1.0/60)
 expect(game.mission.run.time>before[0],"mission advances after resume")
 game.game_flow.start("mission",false,false,false)
 expect(game.game_flow.state=="intro","intro started")
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 expect(game.game_flow.state=="paused" and not game.game_flow.location_visible,"intro focus loss pauses and hides location card")
 var report={"checks":checks,"failures":failures,"frozen_clocks":before,"scope":"Actual Main focus notification handler: title unaffected, playing/intro pause, held and queued input cleared, mission/enemy/weapon/weather clocks frozen, focus-in stays paused and real Resume works. Notification injected; not OS window-switch event delivery or backdrop-clock acceptance."}
 FileAccess.open("res://evidence/focus-pause-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
