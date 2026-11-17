extends SceneTree
func _initialize()->void:call_deferred("run")
func settle(frames:int=12)->void:
 for i in frames:await process_frame
 RenderingServer.force_draw(false)
func key(code:int)->void:
 for pressed in [true,false]:
  var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.fade=0
 var ui=game.game_ui;ui.save_path="";ui.settings.invertY=false;ui.open_panel()
 for i in 8:game._process(0.0);await process_frame
 var controls=[];ui._pad_controls(ui.panel,controls);var toggle;var sensitivity
 for control in controls:
  if control.get_meta("setting_key","")=="invertY":toggle=control
  if control.get_meta("setting_key","")=="sens":sensitivity=control
 var failures=[]
 if toggle==null:push_error("Missing toggle");quit(1);return
 var point=toggle.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);await process_frame
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;Input.parse_input_event(event);await process_frame
 await settle()
 if not ui.settings.invertY or not toggle.button_pressed or absf(toggle.amount-1)>1e-5:failures.append("mouse toggle/apply/animation")
 var image=root.get_texture().get_image();var actual=image.get_pixelv(Vector2i(toggle.get_global_rect().position+Vector2(32,15)));var expected=Color("ffb347")
 if maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))>1.1/255:failures.append("active thumb GPU color")
 image.save_png("res://evidence/panel-toggle-on.png")
 toggle.grab_focus();await key(KEY_SPACE);await settle()
 if ui.settings.invertY or toggle.button_pressed or toggle.amount!=0 or not toggle.focus_visible:failures.append("keyboard toggle/focus")
 sensitivity.grab_focus();toggle.focus_visible=false;ui.pad_nav(1)
 if root.gui_get_focus_owner()!=toggle or not toggle.focus_visible:failures.append("pad focus visibility")
 ui.pad_accept();await settle()
 if not ui.settings.invertY or not toggle.button_pressed:failures.append("pad accept apply")
 var report={"failures":failures,"mouse_keyboard_pad":true,"final_invert_y":ui.settings.invertY,"active_thumb_pixel":[actual.r,actual.g,actual.b],"scope":"Actual Main settings toggle: injected native mouse click and Space key, controller navigation/accept methods, live invertY setting, completed visual state and one GPU thumb color. Not physical controller or full-panel pixel parity."}
 FileAccess.open("res://evidence/panel-toggle-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
