extends SceneTree
func _initialize()->void:call_deferred("run")
func key(code:int,shift:bool=false)->void:
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;event.shift_pressed=shift;Input.parse_input_event(event);await process_frame
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path=""
 for i in 12:await process_frame
 var ui=game.game_ui;ui.buttons.settings.grab_focus();ui.open_panel(true)
 for i in 8:await process_frame
 var failures=[];var content=ui.panel.find_child("OriginalControlContent",true,false);var scroll=ui.panel.find_child("ControlTables",true,false)
 if content==null or content.row_count!=30:failures.append("source controls missing")
 var controls=[];ui._pad_controls(ui.panel,controls)
 if controls.size()!=3:failures.append("static content captured focus")
 await key(KEY_TAB)
 if root.gui_get_focus_owner()!=ui.buttons.settings_tab:failures.append("controls first tab focus")
 await key(KEY_TAB,true)
 if root.gui_get_focus_owner()!=ui.buttons.close:failures.append("controls reverse focus wrap")
 var point=scroll.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);await process_frame
 for i in 4:
  for pressed in [true,false]:
   var wheel=InputEventMouseButton.new();wheel.position=point;wheel.global_position=point;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=pressed;wheel.factor=1.0;Input.parse_input_event(wheel);await process_frame
 if scroll.scroll_vertical<=0:failures.append("native wheel did not scroll")
 var wheel_scroll=scroll.scroll_vertical
 scroll.scroll_vertical=10000
 for i in 4:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/controls-scroll-end.png")
 await key(KEY_ESCAPE)
 if ui.panel_open or root.gui_get_focus_owner()!=ui.buttons.settings:failures.append("controls Escape/focus return")
 var report={"source_rows":content.row_count,"focusable_controls":controls.size(),"wheel_scroll":wheel_scroll,"content_height":content.custom_minimum_size.y,"content_width":content.size.x,"failures":failures,"scope":"Actual Main rich controls pane, three focusable header controls, injected Tab/ShiftTab/Escape and mouse wheel delivery, scroll-end GPU capture. Not whole browser layout or physical device test."}
 FileAccess.open("res://evidence/controls-panel-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
