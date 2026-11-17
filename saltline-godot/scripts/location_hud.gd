extends Control

const TITLE="SALTLINE TERMINAL · BERTH 4 · 05:42"
const SUBTITLE="PORT AUTHORITY BREACH UNIT — ONE BREACHER, NO BACKUP"
class TextLines extends Control:
 var font:Font
 var rows=[]
 var pixels=34
 var spacing=5.44
 var line_height=35.7
 var color=Color("e8e4da")
 func _draw()->void:
  for row in rows.size():
   for i in rows[row].length():
    var p=Vector2(font.get_string_size(rows[row].left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,row*line_height+(line_height-font.get_height(pixels))*.5+font.get_ascent(pixels))
    draw_string(font,p+Vector2(0,1),rows[row][i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,.55))
    draw_string(font,p,rows[row][i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

var shown=false
var alpha=0.0
var opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.5)
var transition_start=0.0
var transition_time=.5
var reveal_time=0.0
var title_mask:Control
var heading:TextLines
var subtitle:TextLines
var card_height=0.0

func _init()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;visible=false
 title_mask=Control.new();title_mask.clip_contents=true;title_mask.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(title_mask)
 heading=TextLines.new();heading.font=preload("res://assets/fonts/big-shoulders-display-700.ttf");heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;title_mask.add_child(heading)
 subtitle=TextLines.new();subtitle.font=preload("res://assets/fonts/ibm-plex-mono-400.ttf");subtitle.pixels=11;subtitle.spacing=1.1;subtitle.line_height=15.4;subtitle.color=Color(Color("e8e4da"),.64);subtitle.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(subtitle)

func show_card(value:bool)->void:
 if value==shown:return
 shown=value;transition_start=alpha;transition_time=0;opacity_transition.set_target(value)
 if value:reveal_time=0

static func reveal_fraction(seconds:float)->float:
 return floor(clampf(seconds/preload("res://scripts/motion_preference.gd").duration(1.1),0,1)*28)/28*1.02

func wrapped_lines(value:String,font:Font,pixels:int,spacing:float,width:float)->Array:
 var rows=[];var row=""
 for word in value.split(" "):
  var next=word if row.is_empty() else row+" "+word
  if not row.is_empty() and font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+next.length()*spacing>width:rows.append(row);row=word
  else:row=next
 rows.append(row);return rows

func update_frame(dt:float)->void:
 transition_time=minf(.5,transition_time+dt)
 alpha=opacity_transition.advance(dt)
 if shown:reveal_time+=dt
 modulate.a=alpha;visible=alpha>0
 var screen=get_viewport_rect().size
 heading.pixels=int(round(clampf(screen.x*.03,19,34)));heading.spacing=heading.pixels*.16;heading.line_height=heading.pixels*1.05
 var title_width=heading.font.get_string_size(TITLE,HORIZONTAL_ALIGNMENT_LEFT,-1,heading.pixels).x+TITLE.length()*heading.spacing
 var subtitle_width=subtitle.font.get_string_size(SUBTITLE,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x+SUBTITLE.length()*1.1
 var width=minf(maxf(0,screen.x-64),maxf(title_width,subtitle_width))
 heading.rows=wrapped_lines(TITLE,heading.font,heading.pixels,heading.spacing,width)
 subtitle.rows=wrapped_lines(SUBTITLE,subtitle.font,11,1.1,width)
 var title_height=heading.rows.size()*heading.line_height
 card_height=title_height+7+subtitle.rows.size()*15.4
 position=Vector2(maxf(16,screen.x*.055),screen.y*.72-card_height)
 title_mask.position=Vector2(16,0);title_mask.size=Vector2(width*reveal_fraction(reveal_time),title_height)
 subtitle.position=Vector2(16,title_height+7)
 heading.queue_redraw();subtitle.queue_redraw();queue_redraw()

func _draw()->void:draw_rect(Rect2(0,2,3,maxf(0,card_height-4)),Color("ffb347"))
