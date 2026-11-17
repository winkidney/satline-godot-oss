class_name SaltlineNavigationHud
extends Control

const BONE=Color("e8e4da")
const SIGNAL=Color("ffb347")
const CARDINAL={0:"N",45:"NE",90:"E",135:"SE",180:"S",225:"SW",270:"W",315:"NW"}
var camera:Camera3D
var player:SaltlinePlayer
var weapon:SaltlineWeapon
var mission:SaltlineMission
var mono:Font
var heading_font:Font
var display:Font
var label_font:Font
var feed_font:Font
var feedback:SaltlineCombatFeedback
var markers=[]
var current_heading=0.0
var cross:Dictionary={}
var compass_width=420.0
var touch_layout=false
var cross_fade=preload("res://scripts/css_opacity_transition.gd").new(.1)
var marks_fade=preload("res://scripts/css_opacity_transition.gd").new(.15)
var gap_transition:Dictionary
var marker_transitions={}
var marker_keys:Array=[]

func _init()->void:
 cross_fade.reset(1.0);marks_fade.reset(1.0)
 gap_transition=_new_transition(0.0,.06,Vector4(0,0,1,1))

func _new_transition(value:float,duration:float,curve:Vector4=Vector4(.25,.1,.25,1))->Dictionary:
 var timing=preload("res://scripts/css_transition_timing.gd").new();timing.duration=duration;timing.curve=curve;timing.reset(value,0.0)
 return {"timing":timing,"initial":value,"clock":0.0,"value":value}

func _transition(state:Dictionary,target:float,dt:float)->float:
 var timing=state.timing
 var current=lerpf(state.initial,float(timing.target),timing.progress(state.clock))
 if timing.retarget(target,current,state.clock):state.initial=current
 state.clock+=dt;state.value=lerpf(state.initial,float(timing.target),timing.progress(state.clock));return state.value

func reset_markers()->void:marker_transitions.clear()

func setup(core:SaltlineMission,view:Camera3D,gun:SaltlineWeapon)->void:
 mission=core;mission.hud_reset.connect(reset_markers);camera=view;player=core.player;weapon=gun;mouse_filter=Control.MOUSE_FILTER_IGNORE
 feed_font=load("res://assets/fonts/barlow-condensed-500.ttf")
 mono=load("res://assets/fonts/ibm-plex-mono-400.ttf");display=load("res://assets/fonts/big-shoulders-display-700.ttf");label_font=load("res://assets/fonts/barlow-condensed-600.ttf")
 heading_font=load("res://assets/fonts/ibm-plex-mono-500.ttf")

func update_frame(dt:float)->void:
 var screen=get_viewport().get_visible_rect().size;size=screen;compass_width=minf(300,screen.x-152) if touch_layout else minf(420,screen.x-40)
 current_heading=SaltlineHudProjection.heading(player.yaw);markers.clear()
 var records=[]
 for relay in mission.relays:
  if not relay.cut:records.append({"pos":relay.o.pos,"short":relay.short,"kind":"relay"})
 if mission.run.allCut and not mission.extraction.is_empty():records.append({"pos":mission.extraction.pos,"short":"EX","kind":"extract"})
 var keys=[]
 for item in records:keys.append(item.kind+":"+item.short)
 if keys!=marker_keys:marker_transitions.clear();marker_keys=keys
 for item in records:
  var result=SaltlineHudProjection.marker(item.pos,item.kind,player.pos,player.yaw,camera.global_transform,camera.fov,camera.near,camera.far,screen,compass_width)
  result.short=item.short;result.kind=item.kind
  var key=item.kind+":"+item.short
  var target=0.0 if result.near else .7 if result.offscreen else .22 if result.dim else .78
  # Newly inserted marker elements start at their first computed CSS value.
  if not marker_transitions.has(key):marker_transitions[key]=_new_transition(target,.25)
  result.alpha=_transition(marker_transitions[key],target,dt);markers.append(result)
 marks_fade.set_target(player.ads<.5);marks_fade.advance(dt)
 cross=SaltlineHudProjection.crosshair(player.ads,player.alive,weapon.state,weapon.spread,camera.fov,screen.y,player.sprinting)
 cross_fade.set_target(cross.visible);cross.alpha=cross_fade.advance(dt)
 cross.gap=_transition(gap_transition,float(cross.gap) if cross.visible else float(gap_transition.timing.target),dt)
 queue_redraw()

func _text(font:Font,value:String,point:Vector2,font_size:int,color:Color,center:bool=true)->void:
 var offset=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5 if center else 0.0
 draw_string(font,point-Vector2(offset,0)+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,color.a*.65))
 draw_string(font,point-Vector2(offset,0),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _diamond(center:Vector2,radius:float,color:Color,filled:bool)->void:
 var points=PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0),center+Vector2(0,-radius)])
 draw_colored_polygon(points,color if filled else Color(.043,.051,.059,color.a*.5));draw_polyline(points,color,1.5,true)

func css_text(font:Font,value:String,point:Vector2,pixels:int,line_height:float,spacing:float,color:Color,center:bool=true)->void:
 var width=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+value.length()*spacing
 var baseline=point+Vector2(-width*.5 if center else 0,(line_height-font.get_height(pixels))*.5+font.get_ascent(pixels))
 for i in value.length():
  var p=baseline+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*spacing,0)
  _text(font,value[i],p,pixels,color,false)

func compass_ticks()->Array:
 var rows=[];var center=size.x*.5
 for tick in range(-90,451,5):
  var x=center-compass_width*.5+SaltlineHudProjection.tape_offset(player.yaw,compass_width)+(tick+90)*4
  var distance=absf(x-center)
  if distance>compass_width*.5:continue
  var degrees=posmod(tick,360);var major=degrees%45==0;var medium=degrees%15==0
  rows.append({"x":x,"degrees":degrees,"major":major,"medium":medium,"fade":clampf((compass_width*.5-distance)/(compass_width*.16),0,1)})
 return rows

func _draw()->void:
 if mono==null:return
 draw_feedback()
 var center=size.x*.5
 for tick in compass_ticks():
  var x=tick.x;var degrees=tick.degrees;var major=tick.major;var medium=tick.medium;var fade=tick.fade
  var height=10 if major else 7 if medium else 4
  var color=BONE;color.a=fade*(1 if major else .8 if medium else .45)
  draw_line(Vector2(x,40-height),Vector2(x,40),color,2 if major else 1)
  if major:
   if degrees%90==0:css_text(display,CARDINAL[degrees],Vector2(x,12),16,16,.64,Color(BONE,fade))
   else:css_text(label_font,CARDINAL[degrees],Vector2(x,12),11,15.4,.88,Color(BONE,fade*.64))
  elif medium:css_text(mono,"%03d"%degrees,Vector2(x,12),9,15.3,0,Color(BONE,fade*.64))
 draw_rect(Rect2(center-1,26,2,16),SIGNAL)
 if size.x>760:css_text(heading_font,"%03d"%(SaltlineHudProjection.js_round(current_heading)%360),Vector2(center+compass_width*.5+6,21),11,11,.66,Color(BONE,.64),false)
 for marker in markers:
  var color=BONE if marker.kind=="extract" else SIGNAL
  var compass_color=Color(color,.55 if marker.edge else 1)
  _diamond(Vector2(center+marker.compass,49),5.656854,compass_color,marker.kind=="extract")
  var distance_text="%dm"%marker.distance
  var short_width=display.get_string_size(marker.short,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+marker.short.length()*.78+4
  var distance_width=mono.get_string_size(distance_text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
  var group_x=center+marker.compass-(short_width+distance_width)*.5
  css_text(display,marker.short,Vector2(group_x,56),13,16,.78,compass_color,false)
  css_text(mono,distance_text,Vector2(group_x+short_width,56),10,16,0,Color(BONE,compass_color.a),false)
  var alpha=float(marker.alpha)*marks_fade.value
  if alpha<=0:continue
  var point=Vector2(marker.x,marker.y)
  _diamond(point,7.07,Color(color,alpha),marker.kind=="extract")
  css_text(display,marker.short,point+Vector2(0,-24),12,12,.96,Color(color,alpha))
  css_text(mono,"%dm"%marker.distance,point+Vector2(0,11),10,10,0,Color(BONE,alpha))
 if float(cross.get("alpha",0.0))>0:
  var point=size*.5;var gap=float(cross.gap);var color=Color(BONE,cross.alpha)
  for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
   draw_line(point+direction*(gap-1),point+direction*(gap+10),Color(0,0,0,.4*cross.alpha),4)
   draw_line(point+direction*gap,point+direction*(gap+9),color,2)
  draw_rect(Rect2(point-Vector2.ONE,Vector2(2,2)),Color(BONE,.85*cross.alpha))

func draw_feedback()->void:
 if feedback==null:return
 var center=size*.5;var alarm=Color("ff5a40")
 var radius=minf(size.y*.72,size.x*.94)*.5
 for arc in feedback.arcs:
  if arc.op<=0:continue
  var angle=deg_to_rad(arc.rot)
  var points=PackedVector2Array()
  for index in 25:
   var theta=deg_to_rad(-114.35+48.7*index/24.0)+angle
   points.append(center+Vector2(cos(theta),sin(theta))*radius*.92)
  draw_polyline(points,Color(alarm,arc.op*.9),radius*.04,true)
  var tip=PackedVector2Array()
  for point in [Vector2(-7,-97),Vector2(0,-106),Vector2(7,-97)]:tip.append(center+(point*radius*.01).rotated(angle))
  draw_polyline(tip,Color(alarm,arc.op*.9),radius*.025,true)
 if feedback.hit_opacity>0:
  var color=alarm if feedback.hit_kind=="kill" else SIGNAL if feedback.hit_kind=="weak" else Color.WHITE
  color.a=feedback.hit_opacity
  for point in [Vector2(-11,-9.5),Vector2(11,-9.5),Vector2(-11,9.5),Vector2(11,9.5)]:
   var direction=Vector2(1 if point.x*point.y>0 else -1,1).normalized()
   var a=center+(point-direction*5.5)*feedback.hit_scale;var b=center+(point+direction*5.5)*feedback.hit_scale
   draw_line(a,b,Color(0,0,0,.35*color.a),(5 if feedback.hit_kind=="kill" else 4)*feedback.hit_scale,true)
   draw_line(a,b,color,(3 if feedback.hit_kind=="kill" else 2)*feedback.hit_scale,true)
 for index in feedback.feed.size():
  var entry:Dictionary=feedback.feed[index]
  var alpha=1-SaltlineCombatFeedback.bezier(clampf(entry.fade_time/entry.fade_duration,0,1),.25,.1,.25,1) if entry.out else 1.0
  var name=entry.kind;var body=" DESTROYED";var weak="WEAK POINT" if entry.weak else ""
  var width=_tracked_width(label_font,name)+_tracked_width(feed_font,body)+(10+_tracked_width(feed_font,weak) if entry.weak else 0)
  var origin=Vector2(size.x-16-width,(150 if touch_layout else size.y*.31)+index*19.5+13)
  origin.x+=_tracked(label_font,name,origin,Color(BONE,alpha))
  origin.x+=_tracked(feed_font,body,origin,Color(BONE,alpha*.64))
  if entry.weak:_tracked(feed_font,weak,origin+Vector2(10,0),Color(SIGNAL,alpha))

func _tracked_width(font:Font,value:String)->float:
 var width=0.0
 for letter in value:width+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+2.34
 return width
func _tracked(font:Font,value:String,position:Vector2,color:Color)->float:
 var width=0.0
 for letter in value:
  _text(font,letter,position+Vector2(width,0),13,color,false)
  width+=font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+2.34
 return width
