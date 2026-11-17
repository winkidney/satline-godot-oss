extends Control

var warning=""
var warning_on=false
var message=""
var warning_remaining=0.0
var message_remaining=0.0
var warning_clock=0.0
var message_target=false
var message_alpha=0.0
var message_opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.3)
var message_start=0.0
var message_transition=.3
var display=preload("res://assets/fonts/big-shoulders-display-700.ttf")
var mono=preload("res://assets/fonts/ibm-plex-mono-400.ttf")

func warn(value:String,seconds:float)->void:
 warning=value;warning_remaining=seconds;warning_clock=0;warning_on=true
func show_message(value:String,seconds:float)->void:
 message=value;message_remaining=seconds if not value.is_empty() else 0;_message_target(not value.is_empty())
func clear()->void:
 warning_remaining=0;warning_on=false;show_message("",0)
func _message_target(value:bool)->void:
 if message_target==value:return
 message_target=value;message_start=message_alpha;message_transition=0;message_opacity_transition.set_target(value)

static func warning_style(seconds:float)->Dictionary:
 if preload("res://scripts/motion_preference.gd").reduced:return {"alpha":1.0,"spacing_em":.24}
 var t=clampf(seconds/3.4,0,1);var opacity=0.0
 if t<.08:opacity=t/.08
 elif t<.14:opacity=lerpf(1,.35,(t-.08)/.06)
 elif t<.2:opacity=lerpf(.35,1,(t-.14)/.06)
 elif t<.82:opacity=1
 else:opacity=1-(t-.82)/.18
 return {"alpha":opacity,"spacing_em":lerpf(.5,.24,minf(t/.08,1))}

func update_frame(dt:float,hud_on:bool)->void:
 warning_clock+=dt
 # Original HUD re() returns before these timers while HUD is hidden.
 if hud_on:
  if warning_remaining>0:
   warning_remaining-=dt
   if warning_remaining<=0:warning_on=false
  if message_remaining>0:
   message_remaining-=dt
   if message_remaining<=0:_message_target(false)
 message_transition=minf(.3,message_transition+dt)
 message_alpha=message_opacity_transition.advance(dt)
 queue_redraw()

func width_of(value:String,font:Font,pixels:int,spacing:float)->float:
 return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+value.length()*spacing
func tracked(value:String,font:Font,pixels:int,spacing:float,point:Vector2,line_height:float,color:Color)->void:
 var baseline=point+Vector2(-width_of(value,font,pixels,spacing)*.5,(line_height-font.get_height(pixels))*.5+font.get_ascent(pixels))
 for i in value.length():
  var p=baseline+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,0)
  draw_string(font,p+Vector2(0,1),value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,color.a*.55))
  draw_string(font,p,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw()->void:
 var screen=get_viewport_rect().size;var center=screen.x*.5
 if warning_on:
  var style=warning_style(warning_clock);var pixels=int(round(clampf(screen.x*.036,20,38)));var spacing=pixels*style.spacing_em
  var value=warning.to_upper();var width=width_of(value,display,pixels,spacing);var color=Color(Color("ffb347"),style.alpha);var top=screen.y*.21
  draw_line(Vector2(center-width*.5,top+.5),Vector2(center+width*.5,top+.5),color,1)
  tracked(value,display,pixels,spacing,Vector2(center,top+10),pixels,color)
  draw_line(Vector2(center-width*.5,top+pixels+18.5),Vector2(center+width*.5,top+pixels+18.5),color,1)
 if message_alpha<=0:return
 var lines=[];var line="";var max_width=screen.x-52
 for word in message.to_upper().split(" "):
  var candidate=word if line.is_empty() else line+" "+word
  if not line.is_empty() and width_of(candidate,mono,11,.88)>max_width:lines.append(line);line=word
  else:line=candidate
 if not message.is_empty():lines.append(line)
 var width=0.0
 for value in lines:width=maxf(width,width_of(value,mono,11,.88))
 var height=lines.size()*15.4+12;var top=screen.y*.77-height
 draw_rect(Rect2(center-width*.5-10,top,width+20,height),Color(.043137,.05098,.058824,.6*message_alpha))
 for i in lines.size():tracked(lines[i],mono,11,.88,Vector2(center,top+6+i*15.4),15.4,Color(Color("e8e4da"),message_alpha))
