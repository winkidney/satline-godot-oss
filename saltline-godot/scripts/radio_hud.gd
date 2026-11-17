extends Control

var text=""
var touch_layout=false
var alpha=0.0
var opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.3)
var target=false
var transition_time=.3
var transition_start=0.0
var body_font=preload("res://assets/fonts/barlow-condensed-500.ttf")
var speaker_font=preload("res://assets/fonts/barlow-condensed-600.ttf")

func update_frame(dt:float,value:String,on:bool)->void:
 text=value
 if on!=target:
  target=on;transition_start=alpha;transition_time=0;opacity_transition.set_target(on)
 transition_time=minf(.3,transition_time+dt)
 alpha=opacity_transition.advance(dt)
 modulate.a=alpha;visible=alpha>0;queue_redraw()

func text_width(value:String,font:Font,pixels:int,spacing:float)->float:
 return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+value.length()*spacing

func lines_for(value:String,width:float,pixels:int)->Array:
 var lines=[];var line=""
 var words=value.split(" ")
 for index in words.size():
  var word=words[index]
  var next=word if line.is_empty() else line+" "+word
  # Inline clone paints both pads, but only the final fragment reserves right padding.
  var available=width-(16 if index==words.size()-1 else 8)
  if not line.is_empty() and text_width(next,body_font,pixels,pixels*.02)>available:lines.append(line);line=word
  else:line=next
 lines.append(line);return lines

func tracked(value:String,font:Font,pixels:int,spacing:float,top:Vector2,line_height:float,color:Color)->void:
 var baseline=top+Vector2(-text_width(value,font,pixels,spacing)*.5,(line_height-font.get_height(pixels))*.5+font.get_ascent(pixels))
 for i in value.length():
  var p=baseline+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,0)
  draw_string(font,p+Vector2(0,1),value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,.55))
  draw_string(font,p,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw()->void:
 var screen=get_viewport_rect().size;var center=screen.x*.5
 var pixels=17 if screen.x<=760 else 19;var spacing=pixels*.02;var line_height=pixels*1.3
 var container_width=minf(620,screen.x-32)
 var lines=lines_for(text,container_width,pixels)
 var height=17+lines.size()*line_height;var y=screen.y*.27 if touch_layout else screen.y*.85-height
 # The CSS speaker's negative right margin cancels trailing letter spacing.
 tracked("CONTROL",speaker_font,11,3.74,Vector2(center+1.87,y),11,Color("ffb347"))
 for i in lines.size():
  var width=text_width(lines[i],body_font,pixels,spacing)
  var line_center=center+maxf(0,(width+16-container_width)*.5)
  if not lines[i].is_empty():draw_rect(Rect2(line_center-width*.5-8,y+17+i*line_height-2,width+16,line_height+4),Color(.043137,.05098,.058824,.6))
  tracked(lines[i],body_font,pixels,spacing,Vector2(line_center,y+17+i*line_height),line_height,Color("e8e4da"))
