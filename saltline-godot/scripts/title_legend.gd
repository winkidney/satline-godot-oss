extends Control
var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/title-legend.json"))
var fonts={}
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 for key in ["label","mono"]:
  var font=load("res://assets/fonts/"+("barlow-condensed-500.ttf" if key=="label" else "ibm-plex-mono-500.ttf")).duplicate();font.oversampling=1.0;fonts[key]=font
 update_layout()
func update_layout()->void:
 var screen=Vector2(get_window().size);var logical=get_viewport_rect().size
 if screen.x<=0 or screen.y<=0:return
 scale=logical/screen;size=Vector2(data.width,data.height)
 var bottom=clampf(screen.y*.055,14,52)+clampf(screen.y*.05,18,56)
 position=Vector2(screen.x-maxf(16,screen.x*.045)-data.width,screen.y-bottom-data.height)*scale
 visible=screen.x>=1180 and screen.y>=600;queue_redraw()
func rgba(values:Array)->Color:return Color(values[0]/255.0,values[1]/255.0,values[2]/255.0,values[3])
func _draw()->void:
 if fonts.is_empty():return
 for box in data.boxes:
  var r=box.rect;var rect=Rect2(r[0],r[1],r[2],r[3]);var background=rgba(box.background)
  if background.a>0:draw_rect(rect,background)
  if box.width>0:
   if box.all:draw_rect(rect.grow(-.5),rgba(box.border),false,1)
   else:draw_line(rect.position+Vector2(0,.5),rect.position+Vector2(rect.size.x,.5),rgba(box.border),1)
 for glyph in data.glyphs:
  var font=fonts[glyph.font];var at=Vector2(glyph.x,glyph.y)
  draw_string(font,at+Vector2(0,1),glyph.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(glyph.pixels),Color(0,0,0,.55))
  draw_string(font,at,glyph.text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(glyph.pixels),rgba(glyph.color))
