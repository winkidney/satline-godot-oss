extends Control

const CIRCUMFERENCE=TAU*19
var text=""
var key="E"
var progress=0.0
var dash_offset=119.38
var active=false
var alpha=0.0
var opacity_transition=preload("res://scripts/css_opacity_transition.gd").new(.15)
var transition_start=0.0
var transition_time=.15
var display=preload("res://assets/fonts/big-shoulders-display-700.ttf")
var label_font=preload("res://assets/fonts/barlow-condensed-600.ttf")

func set_prompt(value:Variant,amount:float=0,button:String="E")->void:
 var enabled=value!=null and not str(value).is_empty()
 if enabled!=active:active=enabled;transition_start=alpha;transition_time=0;opacity_transition.set_target(enabled)
 if not enabled:return
 key=button;text="Hold %s — %s"%[button,value]
 progress=floor(amount*200+.5)/200
 dash_offset=snappedf(CIRCUMFERENCE*(1-progress),.01)

func update_frame(dt:float)->void:
 transition_time=minf(.15,transition_time+dt)
 alpha=opacity_transition.advance(dt)
 modulate.a=alpha;visible=alpha>0;queue_redraw()

func draw_text(font:Font,value:String,pixels:int,spacing:float,point:Vector2,line_height:float,color:Color,center:bool=false)->void:
 var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+value.length()*spacing
 var baseline=point+Vector2(-width*.5 if center else 0,(line_height-font.get_height(pixels))*.5+font.get_ascent(pixels))
 for i in value.length():
  var p=baseline+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,0)
  draw_string(font,p+Vector2(0,1),value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,.55))
  draw_string(font,p,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _draw()->void:
 var screen=get_viewport_rect().size;var caption=text.to_upper();var width=label_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+caption.length()*2.24+22
 var x=(screen.x-60-width)*.5;var y=screen.y*.61;var center=Vector2(x+24,y+24)
 var bone=Color("e8e4da");var signal_color=Color("ffb347")
 draw_circle(center,19,Color(.043137,.05098,.058824,.5));draw_arc(center,19,0,TAU,128,Color(bone,.24),3,true)
 # Original SVG uses circumference rounded to two decimals for dasharray/offset.
 var arc_length=clampf(119.38-dash_offset,0,CIRCUMFERENCE)
 if arc_length>0:draw_arc(center,19,-PI*.5,-PI*.5+arc_length/19,128,signal_color,3,true)
 draw_text(display,key,12 if key.length()>1 else 19,1.2 if key.length()>1 else .76,Vector2(center.x,y),48,bone,true)
 draw_rect(Rect2(x+60,y+9.5,width,29),Color(.043137,.05098,.058824,.6));draw_rect(Rect2(x+60,y+9.5,2,29),signal_color)
 draw_text(label_font,caption,16,2.24,Vector2(x+72,y+16.5),16,signal_color if progress>0 else bone)
