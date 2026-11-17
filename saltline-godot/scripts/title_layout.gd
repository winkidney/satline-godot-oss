extends Control
var ui
var eyebrow
var word
var premise
var mode_label
var difficulty_label
var mode_row:Control
var difficulty_row:Control
var note
var last_size=Vector2.ZERO
var legend_width=float(JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/title-legend.json")).width)
var pick_metrics=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/title-pick-metrics.json"))
var premise_rule=Rect2()
var action_buttons=[]
func _draw()->void:
 draw_line(premise_rule.position,premise_rule.end,Color(ui.BONE,.2),1)
 draw_line(premise_rule.position-Vector2(0,1),premise_rule.position+Vector2(minf(72,premise_rule.size.x),-1),ui.SIGNAL,3)
func setup(owner_ui)->void:
 ui=owner_ui;mouse_filter=Control.MOUSE_FILTER_IGNORE
 eyebrow=preload("res://scripts/title_eyebrow.gd").new();add_child(eyebrow)
 word=ui.TrackedTitle.new();word.font=ui._ui_font(self,ui.display_font);add_child(word)
 premise=preload("res://scripts/title_premise.gd").new();add_child(premise)
 ui._button(self,"DEPLOY",Rect2(0,0,180,52),"deploy",true);ui._button(self,"SETTINGS",Rect2(0,0,170,46),"settings");ui._button(self,"CONTROLS",Rect2(0,0,170,46),"controls")
 action_buttons=[ui.buttons.deploy,ui.buttons.settings,ui.buttons.controls]
 mode_label=tracked_label("MODE");mode_row=Control.new();add_child(mode_row);ui._choices(mode_row,"mode",["mission","holdout"],Vector2.ZERO,130)
 difficulty_label=tracked_label("DIFFICULTY");difficulty_row=Control.new();add_child(difficulty_row);ui._choices(difficulty_row,"difficulty",["standard","hard","brutal"],Vector2.ZERO,96)
 ui.mode_note=preload("res://scripts/title_premise.gd").new();ui.mode_note.font_path="res://assets/fonts/ibm-plex-mono-400.ttf";ui.mode_note.tracking_em=0;ui.mode_note.line_height_em=1.4;ui.mode_note.text_color=Color("8d9aa3");add_child(ui.mode_note);ui._mode_note()
 note=preload("res://scripts/title_premise.gd").new();note.font_path="res://assets/fonts/ibm-plex-mono-400.ttf";note.text="Every surface and machine was generated procedurally. Nothing is downloaded during play.";note.tracking_em=.04;note.line_height_em=1.5;note.text_color=Color("8d9aa3");add_child(note)
 update_layout()
func tracked_label(value:String):
 var label=preload("res://scripts/title_premise.gd").new();label.text=value;label.tracking_em=.24;label.line_height_em=1;label.text_color=Color("8d9aa3");add_child(label);return label
func update_layout()->void:
 var screen=Vector2(get_window().size);var logical=get_viewport_rect().size
 if screen.x<=0 or screen.y<=0:return
 scale=logical/screen;size=screen
 var narrow=screen.x<=760;var short=screen.y<=520
 var left=16.0 if narrow else maxf(16,screen.x*.055);var right=16.0 if narrow else maxf(16,screen.x*.045);var width=screen.x-left-right
 # Measured original legend min-content width with the bundled source fonts.
 if screen.x>=1180 and screen.y>=600:width-=legend_width+32
 var font_size=clampf(screen.x*(.2 if narrow else .155),52,150 if narrow else 208)
 if short:font_size=clampf(screen.y*.2,40,120)
 word.font_size=font_size;word.size=Vector2(width,font_size*.8);word.queue_redraw()
 var eyebrow_height=eyebrow.layout(width,narrow)
 var premise_pixels=clampf(screen.x*.0155,17,22)
 var premise_height=premise.layout(minf(width,40*premise_pixels),premise_pixels)
 var mode_note_height=ui.mode_note.layout(minf(width,430),11);var note_height=note.layout(minf(width,343.1875),11)
 var y=0.0;eyebrow.position=Vector2(left,y);y+=eyebrow_height+(8 if short else clampf(screen.y*.02,10,22))
 word.position=Vector2(left-font_size*.035,y);y+=font_size*.8+(10 if short else clampf(screen.y*.022,12,24))
 premise_rule=Rect2(left,y,premise.size.x,0)
 premise.position=Vector2(left,y+(11 if short else 17));y+=(11 if short else 17)+premise_height;queue_redraw()
 y+=12 if short else clampf(screen.y*.03,16,28)
 var primary_height=44.0 if short else 52.0;var secondary_height=40.0 if short else 46.0
 if narrow:
  action_buttons[0].position=Vector2(left,y);action_buttons[0].size=Vector2(width,primary_height);action_buttons[0].custom_minimum_size=Vector2(0,primary_height);y+=primary_height+10
  for i in 2:
   var button=action_buttons[i+1];button.position=Vector2(left+i*(width+10)*.5,y);button.custom_minimum_size=Vector2(0,secondary_height);button.size=Vector2((width-10)*.5,secondary_height)
  y+=secondary_height
 else:
  var x=left;var row_height=primary_height
  for i in 3:
   var button=action_buttons[i];var button_width=[168,123,128][i]
   if x>left and x+button_width>left+width:x=left;y+=row_height+10;row_height=secondary_height
   button.position=Vector2(x,y);button.custom_minimum_size=Vector2(button_width,primary_height if i==0 else secondary_height);button.size=button.custom_minimum_size;x+=button_width+10
  y+=row_height
 y+=clampf(screen.y*.022,12,20)
 var pick_width=minf(width,430);var label_width=float(pick_metrics.label_width);var column_gap=float(pick_metrics.column_gap);var choice_width=maxf(60,pick_width-label_width-column_gap)
 mode_label.layout(label_width,11);difficulty_label.layout(label_width,11)
 mode_label.position=Vector2(left,y+11.5);mode_row.position=Vector2(left+label_width+column_gap,y)
 difficulty_label.position=Vector2(left,y+53.5);difficulty_row.position=Vector2(left+label_width+column_gap,y+42)
 for row in [mode_row,difficulty_row]:
  var count=row.get_child_count()
  for i in count:
   var button=row.get_child(i);var button_width=(choice_width+count-1)/count;button.custom_minimum_size=Vector2(0,34);button.position=Vector2(i*(button_width-1),0);button.size=Vector2(button_width,34)
 y+=84;ui.mode_note.position=Vector2(left,y);y+=maxf(15,mode_note_height)
 y+=10 if short else clampf(screen.y*.026,14,26);note.position=Vector2(left,y);y+=note_height
 var bottom=clampf(screen.y*.055,14,52)+clampf(screen.y*.05,18,56)
 position=Vector2(0,screen.y-bottom-y)*scale
 last_size=screen
