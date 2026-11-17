extends Control

var mode="complete"
var rows=[]
var rating=""
var font_label=preload("res://assets/fonts/barlow-condensed-500.ttf")
var font_kicker=preload("res://assets/fonts/barlow-condensed-600.ttf")
var font_mono=preload("res://assets/fonts/ibm-plex-mono-500.ttf")
var font_display=preload("res://assets/fonts/big-shoulders-display-900.ttf")
var heading_pixels=44.0
var heading_y=22.0
var rating_pixels=46.0
var row_padding=9.0
var bottom_border=true
var row_height=34.0
var stats_y=0.0
var pause_hint="Resume recaptures the mouse."
const BONE=Color("e8e4da")
const STEEL=Color("8d9aa3")
const SIGNAL=Color("ffb347")

func configure(screen:String,statistics:Array,grade:String="")->void:
 mode=screen;rows=statistics;rating=grade
 mouse_filter=Control.MOUSE_FILTER_IGNORE

func layout(screen:Vector2)->void:
 var short=screen.y<=520
 heading_pixels=clampf(screen.x*.086,30,44) if mode=="complete" else clampf(screen.y*.11,30,62) if short else clampf(screen.x*.11,40,62)
 heading_y=18 if short else 22;rating_pixels=34 if short else 46;row_height=28 if short else 34;row_padding=6 if short else 9
 stats_y=heading_y+heading_pixels*.86+(8 if short else 12)
 # The rating's top margin collapses into the heading's bottom margin.
 if mode=="complete":stats_y+=rating_pixels*.9+12
 bottom_border=not (mode=="dead" and rows.size()==2)
 var content_height=stats_y+rows.size()*row_height+(1 if bottom_border else 0) if mode!="paused" else stats_y+(1 if pause_hint.is_empty() else 16.5)
 custom_minimum_size=Vector2(0,content_height);mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_redraw()

func text_width(font:Font,value:String,pixels:float,spacing:float)->float:
 var raster=int(ceil(pixels));return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,raster).x*pixels/raster+value.length()*spacing
func tracked(font:Font,value:String,point:Vector2,pixels:float,line_height:float,spacing:float,color:Color,right:bool=false)->void:
 var raster=int(ceil(pixels));var ratio=pixels/raster
 var p=point+Vector2(-text_width(font,value,pixels,spacing) if right else 0,(line_height-font.get_height(raster)*ratio)*.5+font.get_ascent(raster)*ratio)
 for i in value.length():
  var at=p+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,raster).x*ratio+i*spacing,0)
  draw_set_transform(at,0,Vector2.ONE*ratio);draw_string(font,Vector2.ZERO,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,raster,color)
 draw_set_transform(Vector2.ZERO)

func _draw()->void:
 var kicker={"paused":"OPERATION ON HOLD","dead":"BREACHER DOWN","complete":"BERTH 4 · DEBRIEF"}[mode]
 var heading={"paused":"PAUSED","dead":"SIGNAL LOST","complete":"SALTLINE IS DARK"}[mode]
 tracked(font_kicker,kicker,Vector2.ZERO,12,12,3.36,STEEL)
 tracked(font_display,heading,Vector2(0,heading_y),heading_pixels,heading_pixels*.86,heading_pixels*.08,Color("ff5a40") if mode=="dead" else BONE)
 if mode=="paused":
  tracked(preload("res://assets/fonts/ibm-plex-mono-400.ttf"),pause_hint,Vector2(0,stats_y),11,16.5,.44,STEEL);return
 if mode=="complete":
  var top=stats_y-12-rating_pixels*.9
  tracked(font_label,"RATING",Vector2(0,top+rating_pixels*.9-13),13,13,2.34,STEEL)
  tracked(font_display,rating.to_upper(),Vector2(size.x,top),rating_pixels,rating_pixels*.9,rating_pixels*.08,SIGNAL,true)
 for i in rows.size():
  var y=stats_y+i*row_height
  draw_line(Vector2(0,y+.5),Vector2(size.x,y+.5),Color(BONE,.2),1)
  tracked(font_label,str(rows[i][0]).to_upper(),Vector2(0,y+row_padding+2),13,13,2.34,STEEL)
  tracked(font_mono,str(rows[i][1]),Vector2(size.x,y+row_padding),16,16,0,BONE,true)
 if bottom_border:draw_line(Vector2(0,stats_y+rows.size()*row_height+.5),Vector2(size.x,stats_y+rows.size()*row_height+.5),Color(BONE,.2),1)
