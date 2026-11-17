class_name SaltlineObjectiveHud
extends Control

const BONE=Color("e8e4da")
const SIGNAL=Color("ffb347")
var label_font=preload("res://assets/fonts/barlow-condensed-600.ttf")
var mono=preload("res://assets/fonts/ibm-plex-mono-500.ttf")
var text=""
var elapsed=0.0
var characters=0
var flash=0.0
var done=0
var total=3
var tally=""

func set_objective(value:String)->void:
 if text==value:return
 text=value;elapsed=0;characters=0;flash=.9;queue_redraw()

func update_frame(dt:float,value:String,cut:int,count:int,tally_text:String="")->void:
 set_objective(value);done=cut;total=count;tally=tally_text
 if characters<text.length():
  elapsed+=dt*46;characters=mini(text.length(),int(floor(elapsed)))
 flash=maxf(0,flash-dt);queue_redraw()

func width_of(value:String,font:Font,pixels:int,spacing:float)->float:
 return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+maxi(0,value.length()-1)*spacing

func tracked(value:String,origin:Vector2,font:Font,pixels:int,spacing:float,color:Color)->void:
 for i in value.length():
  var p=origin+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,font.get_ascent(pixels))
  draw_string(font,p+Vector2(0,1),value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,.55))
  draw_string(font,p,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func wrapped(value:String,width:float,pixels:int)->Array:
 var lines=[];var current=""
 for word in value.split(" "):
  var candidate=word if current.is_empty() else current+" "+word
  if not current.is_empty() and width_of(candidate,label_font,pixels,pixels*.05)>width:lines.append(current);current=word
  else:current=candidate
 lines.append(current);return lines

func _draw()->void:
 if text.is_empty():return
 var screen=get_viewport_rect().size;var narrow=screen.x<=760;var pixels=17 if narrow else 20
 position.y=78 if narrow else 16
 var available=(screen.x*.62 if narrow else minf(300,screen.x*.42))-14
 var lines=wrapped(text.left(characters).to_upper(),available,pixels)
 var line_height=pixels*1.1;var relay_y=17+maxf(22,lines.size()*line_height)+9
 var flash_progress=clampf((.9-flash)/preload("res://scripts/motion_preference.gd").duration(.9),0,1)
 var border=SIGNAL.lerp(BONE,pow(1-flash_progress,2))
 draw_rect(Rect2(0,0,2,relay_y+11),border)
 tracked("OBJECTIVE",Vector2(14,0),label_font,11,2.86,Color(BONE,.72))
 for i in lines.size():tracked(lines[i],Vector2(14,17+i*line_height),label_font,pixels,pixels*.05,BONE)
 var caption="RELAYS" if tally.is_empty() else tally.to_upper()
 tracked(caption,Vector2(14,relay_y),label_font,11,2.42 if tally.is_empty() else 1.76,Color(BONE,.72) if tally.is_empty() else BONE)
 if not tally.is_empty():return
 var x=14+width_of(caption,label_font,11,2.42)+9
 for i in total:
  if i<done:draw_rect(Rect2(x,relay_y+1,9,9),SIGNAL)
  else:draw_rect(Rect2(x,relay_y+1,9,9),BONE,false,1.5)
  x+=14
 x+=5
 tracked("%d/%d"%[done,total],Vector2(x,relay_y),mono,11,.44,BONE)
