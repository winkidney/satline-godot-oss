extends SceneTree
var game
var failures=[]
var samples=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path=""
 for i in 30:await process_frame
 for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(640,360),Vector2i(320,568)]:
  root.size=dimensions
  for i in 5:await process_frame
  game.game_ui.open_panel()
  for i in 5:await process_frame
  var ui=game.game_ui;var logical=root.get_visible_rect().size;var factor=Vector2(dimensions)/logical
  var rect=ui.panel.get_global_rect();var physical=Rect2(rect.position*factor,rect.size*factor)
  if absf(physical.size.x-minf(440,dimensions.x))>1 or absf(physical.size.y-dimensions.y)>1 or absf(physical.end.x-dimensions.x)>1:failures.append([dimensions,"drawer bounds",physical])
  var controls=[];ui._pad_controls(ui.panel,controls)
  for control in controls:
   if control is HSlider and control.get_meta("setting_key","")=="fov":control.grab_focus()
  for i in 5:await process_frame
  var scroll=ui.panel.find_child("SettingsScroll",true,false)
  var before=scroll.scroll_vertical;ui.buttons.fullscreen.grab_focus()
  for i in 5:await process_frame
  if dimensions.y<720 and scroll.scroll_vertical<=0:failures.append([dimensions,"focus did not scroll"])
  samples.append({"window":[dimensions.x,dimensions.y],"logical":[logical.x,logical.y],"drawer_position":[physical.position.x,physical.position.y],"drawer_size":[physical.size.x,physical.size.y],"scroll":scroll.scroll_vertical,"before":before})
  RenderingServer.force_draw(false);var rendered=root.get_texture().get_image()
  if rendered.get_size()!=dimensions:failures.append([dimensions,"actual capture size",rendered.get_size()])
  rendered.save_png("res://evidence/settings-%dx%d.png"%[dimensions.x,dimensions.y])
  ui.close_panel()
 var report={"failures":failures,"samples":samples,"scope":"Actual GPU window sizes, settings drawer physical bounds and focused FOV/fullscreen auto-scroll. Reopens pane for each width; does not prove preserved focus/row layout during live width changes, HiDPI or browser pixel identity."}
 FileAccess.open("res://evidence/panel-sizes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
