extends SceneTree
var game
var failures=[]
var samples=[]
var pick_checks=0
var pick_maximum_error=0.0
func _initialize()->void:call_deferred("run")
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path=""
 game.game_ui._select("mode","mission");game.game_ui._select("difficulty","hard")
 for i in 30:await process_frame
 for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(640,360),Vector2i(320,568)]:
  root.size=dimensions
  for i in 8:await process_frame
  var ui=game.game_ui;var ratio=Vector2(dimensions)/root.get_visible_rect().size
  var references=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/title-dom-reference.json"))
  for reference in references.rows:
   if reference.width!=dimensions.x or reference.height!=dimensions.y:continue
   var eyebrow_height=reference.boxes[".m-eyebrow"].height
   if absf(ui.responsive_title.eyebrow.layout_height-eyebrow_height)>.03:failures.append([dimensions,"source eyebrow flex height",ui.responsive_title.eyebrow.layout_height,eyebrow_height])
   var premise_height=ui.responsive_title.premise.layout_height+(11 if dimensions.y<=520 else 17)
   if absf(premise_height-reference.boxes[".m-premise"].height)>.03:failures.append([dimensions,"source premise height",premise_height,reference.boxes[".m-premise"].height])
   var expected_font=float(reference.boxes[".m-word"].font.trim_suffix("px"))
   if absf(ui.responsive_title.word.font_size-expected_font)>.001:failures.append([dimensions,"source fractional title font"])
   var layout=ui.responsive_title;var origin=layout.mode_row.global_position*ratio;origin.x=layout.mode_label.global_position.x*ratio.x
   var nodes=[layout.mode_label]+layout.mode_row.get_children()+[layout.difficulty_label]+layout.difficulty_row.get_children()+[ui.mode_note]
   for n in nodes.size():
    var rect=nodes[n].get_global_rect();var values=[rect.position.x*ratio.x-origin.x,rect.position.y*ratio.y-origin.y,rect.size.x*ratio.x,rect.size.y*ratio.y];var source=reference.picks[n];var expected=[source.x,source.y,source.width,source.height]
    for i in 4:
     pick_checks+=1;var error=absf(values[i]-expected[i]);pick_maximum_error=maxf(pick_maximum_error,error)
     if error>.04:failures.append([dimensions,"source pick cell",n,i,values[i],expected[i]])
   if absf(origin.x-reference.boxes[".m-pick"].x)>.06 or absf(origin.y-reference.boxes[".m-pick"].y)>.06:failures.append([dimensions,"source pick origin",origin])
   var box=reference.boxes[".m-legend"]
   if box.width==0:
    if ui.title_legend.visible:failures.append([dimensions,"legend should be hidden"])
   else:
    var rect=ui.title_legend.get_global_rect();var values=[rect.position.x*ratio.x,rect.position.y*ratio.y,rect.size.x*ratio.x,rect.size.y*ratio.y];var expected=[box.x,box.y,box.width,box.height]
    for i in 4:
     if absf(values[i]-expected[i])>.02:failures.append([dimensions,"source legend bounds",i,values[i],expected[i]])
  var buttons={}
  for action in ["deploy","settings","controls"]:
   var rect=ui.buttons[action].get_global_rect();var physical=Rect2(rect.position*ratio,rect.size*ratio);buttons[action]=[physical.position.x,physical.position.y,physical.size.x,physical.size.y]
   if physical.position.x<0 or physical.position.y<0 or physical.end.x>dimensions.x+1 or physical.end.y>dimensions.y+1:failures.append([dimensions,action,"button clipped",physical])
  for choice in ui.choices:
   if choice.key not in ["mode","difficulty"]:continue
   var rect=choice.button.get_global_rect();var physical=Rect2(rect.position*ratio,rect.size*ratio)
   if physical.end.x>dimensions.x+1 or physical.end.y>dimensions.y+1:failures.append([dimensions,choice.key,"choice clipped",physical])
  RenderingServer.force_draw(false);var rendered=root.get_texture().get_image()
  if rendered.get_size()!=dimensions:failures.append([dimensions,"capture size"])
  rendered.save_png("res://evidence/title-%dx%d.png"%[dimensions.x,dimensions.y]);samples.append({"window":[dimensions.x,dimensions.y],"font":ui.responsive_title.word.font_size,"eyebrow_height":ui.responsive_title.eyebrow.layout_height,"buttons":buttons})
 var report={"failures":failures,"pick_checks":pick_checks,"pick_maximum_error":pick_maximum_error,"samples":samples,"scope":"Actual title four window sizes, source DOM eyebrow/premise heights, fractional title font, legend and eight pick-cell rectangles/origin; physical action bounds and capture sizes. Fixed mission/hard fixture. No full source pixels, all text bounds, HiDPI or live input acceptance."}
 FileAccess.open("res://evidence/title-sizes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
