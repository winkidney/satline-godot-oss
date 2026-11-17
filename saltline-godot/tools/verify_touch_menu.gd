extends SceneTree
var game
var frame=0
var failures=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
func tap(point:Vector2,on:bool)->void:
 var e=InputEventScreenTouch.new();e.index=0;e.position=point;e.pressed=on;Input.parse_input_event(e)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==15:
  RenderingServer.force_draw(false);var image=root.get_texture().get_image();var x=image.get_width()/2
  for y in [0,image.get_height()-1]:
   var color=image.get_pixel(x,y)
   if color.r+color.g+color.b>1e-6:failures.append("title bar edge not black")
 if frame==20:tap(game.game_ui.buttons.settings.get_global_rect().get_center(),true)
 if frame==21:tap(game.game_ui.buttons.settings.get_global_rect().get_center(),false)
 if frame==30 and not game.game_ui.panel_open:failures.append("touch settings click")
 if frame==30 and game.game_ui.title_bars.amount!=1:failures.append("panel hid title bars")
 if frame==31:tap(game.game_ui.buttons.controls_tab.global_position+Vector2(40,18),true)
 if frame==32:tap(game.game_ui.buttons.controls_tab.global_position+Vector2(40,18),false)
 if frame==35 and game.game_ui.panel_tab!="controls":failures.append("touch controls tab")
 if frame==36:tap(game.game_ui.buttons.settings_tab.global_position+Vector2(40,18),true)
 if frame==37:tap(game.game_ui.buttons.settings_tab.global_position+Vector2(40,18),false)
 if frame==39 and game.game_ui.panel_tab!="settings":failures.append("touch settings tab")
 if frame==40:tap(game.game_ui.buttons.close.global_position+Vector2(40,18),true)
 if frame==41:tap(game.game_ui.buttons.close.global_position+Vector2(40,18),false)
 if frame==50 and game.game_ui.panel_open:failures.append("touch close settings")
 if frame==60:tap(game.game_ui.buttons.deploy.get_global_rect().get_center(),true)
 if frame==61:tap(game.game_ui.buttons.deploy.get_global_rect().get_center(),false)
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame==70 and game.game_flow.state!="intro":failures.append("touch deploy")
 if frame==70 and not (game.game_ui.title_bars.amount>0 and game.game_ui.title_bars.amount<1):failures.append("bar exit not animating")
 if frame==120 and (game.game_ui.title_bars.visible or game.game_ui.title_bars.amount!=0):failures.append("bar exit not complete")
 if frame==240:
  if game.game_flow.state!="playing":failures.append("touch deployment reaches playing")
  if game.weapon.shot_count!=0:failures.append("menu touch leaked into shooting")
  finishing=true;call_deferred("finish")
 return false
func finish()->void:
 var report={"frames":frame,"state":game.game_flow.state,"touch":game.source_touch_input.enabled,"failures":failures,"scope":"Actual native GUI via ScreenTouch and Godot emulated mouse: title Settings, Close, Deploy, intro/playing and no leaked fire. Desktop injected events, not physical touchscreen or all settings interactions."}
 FileAccess.open("res://evidence/touch-menu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
