extends SceneTree
var failures=[]
var snapshots=[]
var game
func expect(value:bool,label:String)->void:
 if not value:failures.append(label)
func snapshot(label:String,mode:int)->void:
 snapshots.append({"action":label,"mouse_mode":Input.mouse_mode,"touch":game.source_touch_input.enabled,"state":game.game_flow.state})
 expect(Input.mouse_mode==mode,label+" mouse capture")
func _initialize()->void:call_deferred("run")
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path="";game.game_flow.storage_path=""
 expect(game.game_flow.capture_mouse.get_connections().size()==1,"real capture callback missing")
 var touch=InputEventScreenTouch.new();touch.index=1;touch.position=Vector2(100,100);touch.pressed=true
 game._touch_event(touch)
 game.game_flow.start("mission",false,false,true);snapshot("touch deploy",Input.MOUSE_MODE_VISIBLE)
 game.enemy_manager.clear();game.game_flow.pause();snapshot("touch pause",Input.MOUSE_MODE_VISIBLE)
 game.game_ui._layout_card()
 expect(game.game_ui.card_content.pause_hint.is_empty(),"touch desktop hint retained")
 expect(absf(game.game_ui.card_content.custom_minimum_size.y-game.game_ui.card_content.stats_y-1)<.0001,"touch empty hint min-height")
 for frame in 4:
  game._process(0.0);await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/touch-capture-paused.png")
 game.game_ui.buttons.resume.pressed.emit();snapshot("touch resume",Input.MOUSE_MODE_VISIBLE)
 game.game_flow.retry();snapshot("touch retry",Input.MOUSE_MODE_VISIBLE)
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;game.touch_last_start_ms=-1000
 game._game_input_event(click);snapshot("touch physical mouse click",Input.MOUSE_MODE_VISIBLE)
 game.source_touch_input.enabled=false
 game.game_flow.start("mission",false,false,true);snapshot("desktop deploy",Input.MOUSE_MODE_CAPTURED)
 game.game_flow.pause();snapshot("desktop pause",Input.MOUSE_MODE_VISIBLE)
 game.game_ui._layout_card()
 expect(game.game_ui.card_content.pause_hint=="Resume recaptures the mouse.","desktop hint missing")
 expect(absf(game.game_ui.card_content.custom_minimum_size.y-game.game_ui.card_content.stats_y-16.5)<.0001,"desktop hint line-height")
 game.game_ui.buttons.resume.pressed.emit();snapshot("desktop resume",Input.MOUSE_MODE_CAPTURED)
 game.game_flow.retry();snapshot("desktop retry",Input.MOUSE_MODE_CAPTURED)
 await process_frame;RenderingServer.force_draw(false)
 var report={"failures":failures,"snapshots":snapshots,"scope":"Actual Main capture callback retained; injected first native touch, Deploy/Pause/Resume/Retry and physical mouse click in touch mode; desktop comparison and paused hint min-height from original CSS. No physical touchscreen."}
 FileAccess.open("res://evidence/touch-capture-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
