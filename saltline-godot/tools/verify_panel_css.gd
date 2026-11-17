extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.fade=0;game._process(0.0);var ui=game.game_ui;ui.save_path="";ui.open_panel()
 for i in 8:game._process(0.0);await process_frame
 RenderingServer.force_draw(false)
 var failures=[];var checks=0;var image=root.get_texture().get_image();var bone=Color("e8e4da");var signal_color=Color("ffb347")
 for key in ["settings_tab","controls_tab"]:
  var tab=ui.buttons[key];checks+=1
  if tab.get_script()!=preload("res://scripts/panel_tab.gd") or tab.selected!=(key=="settings_tab"):failures.append("tab "+key)
 for key in ["close","fullscreen"]:
  var button=ui.buttons[key];checks+=1
  if button.get_script()!=preload("res://scripts/title_button.gd") or button.pixels!=12:failures.append("small CSS button "+key)
 var previous={};var choices=0
 for choice in ui.choices:
  if not ui.panel.is_ancestor_of(choice.button):continue
  var button=choice.button;var key=choice.key;choices+=1;checks+=1
  if not button.panel_segmented or button.pixels!=13 or absf(button.size.y-40)>.01:failures.append("panel segmented configuration "+key)
  if previous.has(key):
   checks+=1
   if absf(button.position.x-previous[key].get_rect().end.x+1)>.01:failures.append("segment overlap "+key)
  previous[key]=button
  if button.selected:
   var point=Vector2i(button.get_global_rect().position+Vector2(4,4));var actual=image.get_pixelv(point);checks+=1
   if maxf(absf(actual.r-bone.r),maxf(absf(actual.g-bone.g),absf(actual.b-bone.b)))>1.1/255:failures.append("selected segment GPU color "+key)
  elif button.state_colors()[0].a!=0:failures.append("unselected segment background "+key)
 var controls=[];ui._pad_controls(ui.panel,controls);var sliders=0
 for control in controls:
  if not control is HSlider:continue
  sliders+=1;checks+=1
  if control.get_script()!=preload("res://scripts/panel_slider.gd") or control.get_theme_icon("grabber").get_size()!=Vector2(10,22):failures.append("slider source grabber")
  var center=control.get_global_rect().position+Vector2(5+(control.size.x-10)*(control.value-control.min_value)/(control.max_value-control.min_value),control.size.y*.5)
  var actual=image.get_pixelv(Vector2i(center));checks+=1
  if maxf(absf(actual.r-signal_color.r),maxf(absf(actual.g-signal_color.g),absf(actual.b-signal_color.b)))>1.1/255:failures.append("slider GPU color "+str(control.get_meta("setting_key")))
 for control in controls:
  if not control is HSlider or control.get_meta("setting_key","")!="sens":continue
  var point=control.get_global_rect().position+Vector2(5+(control.size.x-10)*.75,control.size.y*.5)
  var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion);await process_frame
  for pressed in [true,false]:
   var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;Input.parse_input_event(event);await process_frame
  if absf(ui.settings.sens-2.3)>.051:failures.append("native slider click did not apply sensitivity")
  checks+=1
 image.save_png("res://evidence/panel-css-settings.png")
 ui.buttons.controls_tab.pressed.emit();await process_frame
 if ui.panel_tab!="controls" or not ui.buttons.controls_tab.selected or ui.buttons.settings_tab.selected:failures.append("tab switch signal")
 var report={"checks":checks,"panel_choices":choices,"sliders":sliders,"failures":failures,"scope":"Actual Main panel tab/small/segmented/slider renderer wiring, original CSS dimensions/colors, adjacent1px border overlap, selected and slider GPU color samples, live tab action. Not whole layout/font pixel parity; sliders retain native range/input behavior."}
 FileAccess.open("res://evidence/panel-css-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
