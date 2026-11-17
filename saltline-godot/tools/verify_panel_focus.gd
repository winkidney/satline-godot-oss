extends SceneTree
var game
var frame=0
var failures=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path=""
func key(code:int,shift:bool=false)->void:
 for on in [true,false]:
  var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=on;e.shift_pressed=shift;Input.parse_input_event(e)
func expect(value:bool,label:String)->void:
 if not value:failures.append(label)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 var ui=game.game_ui
 if frame==15:ui.buttons.settings.grab_focus();ui.open_panel()
 if frame==20:expect(root.gui_get_focus_owner()==ui.panel,"dialog initial focus");key(KEY_TAB)
 if frame==25:expect(root.gui_get_focus_owner()==ui.buttons.settings_tab,"Tab enters first control");key(KEY_TAB,true)
 if frame==30:expect(root.gui_get_focus_owner()==ui.buttons.fullscreen,"Shift Tab wraps last");key(KEY_TAB)
 if frame==35:
  expect(root.gui_get_focus_owner()==ui.buttons.settings_tab,"Tab wraps first")
  var controls=[];ui._pad_controls(ui.panel,controls)
  for control in controls:
   if control is HSlider and control.get_meta("setting_key","")=="sens":control.grab_focus()
  ui._select("sens",1.0);ui.pad_adjust(1)
 if frame==40:
  expect(ui.setting_outputs.sens.text=="1.10×","sensitivity readout")
  ui._select("fov",83);expect(ui.setting_outputs.fov.text=="83°","FOV readout")
  expect("Difficulty applies" in ui.quality_note.text,"quality / difficulty note")
 if frame==42:
  RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/settings-values.png")
  key(KEY_ESCAPE)
 if frame==45:
  expect(not ui.panel_open,"Escape closes dialog")
  expect(root.gui_get_focus_owner()==ui.buttons.settings,"return prior focus")
  expect(game.game_flow.state=="title","Escape did not toggle game state")
 if frame==50:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 var report={"frames":frame,"failures":failures,"scope":"Actual Main GUI focus with injected Tab/ShiftTab/Escape; dialog entry, wrap, close, prior focus restoration. Direct slider pad_adjust/select exercises live sensitivity/FOV readouts and note. No physical keyboard or pixel parity."}
 FileAccess.open("res://evidence/panel-focus.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
