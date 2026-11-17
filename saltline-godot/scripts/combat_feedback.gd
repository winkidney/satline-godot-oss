class_name SaltlineCombatFeedback
extends RefCounted

var arcs:Array=[]
var feed:Array=[]
var last_feed:Dictionary={}
var last_kill_frame=-1
var hit_kind="hit"
var animations:Array=[]
var hit_opacity=0.0
var hit_scale=1.0

func _init()->void:
 for index in 4:arcs.append({"life":0.0,"max":0.0,"src":Vector3.ZERO,"op":-1.0,"rot":1e9})

func enemy_killed(kind:String,frame:int)->void:
 var entry={"kind":kind.to_upper() if not kind.is_empty() else "MACHINE","life":4.2,"weak":false,"out":false,"fade_time":0.0}
 feed.append(entry)
 while feed.size()>4:feed.pop_front()
 last_feed=entry;last_kill_frame=frame

func enemy_hit(killed:bool,weak:bool,part:String,frame:int)->void:
 hit_kind="kill" if killed else "weak" if weak or part=="weak" else "hit"
 animations.append({"time":0.0,"duration":.42 if hit_kind=="kill" else .24,"scale":1.5 if hit_kind in ["weak","kill"] else 1.15})
 if killed and weak and not last_feed.is_empty() and last_kill_frame==frame and not last_feed.weak:last_feed.weak=true

func player_hit(from_position:Variant)->void:
 if not from_position is Vector3:return
 var slot:Dictionary=arcs[0]
 for arc in arcs:
  if arc.life<=0:slot=arc;break
  if arc.life<slot.life:slot=arc
 slot.src=from_position;slot.life=1.5;slot.max=1.5

func reset()->void:
 feed.clear()
 for arc in arcs:arc.life=0

static func bezier(t:float,x1:float,y1:float,x2:float,y2:float)->float:
 var lo=0.0;var hi=1.0;var u=t
 for index in 32:
  var x=3*(1-u)*(1-u)*u*x1+3*(1-u)*u*u*x2+u*u*u
  if x<t:lo=u
  else:hi=u
  u=(lo+hi)*.5
 return 3*(1-u)*(1-u)*u*y1+3*(1-u)*u*u*y2+u*u*u

func update(dt:float,player_pos:Vector3,yaw:float,shown:bool)->void:
 # Browser animations run even while HUD simulation is hidden by pause/death.
 for entry in feed:
  if entry.out:entry.fade_time+=dt
 for index in range(animations.size()-1,-1,-1):
  animations[index].time+=dt
  if animations[index].time>=animations[index].duration:animations.remove_at(index)
 hit_opacity=0
 if not animations.is_empty():
  var animation:Dictionary=animations.back();var t=bezier(animation.time/animation.duration,0,0,.58,1)
  hit_opacity=1 if t<=.35 else 1-(t-.35)/.65
  hit_scale=lerpf(animation.scale,1,t/.35) if t<=.35 else lerpf(1,.92,(t-.35)/.65)
 if not shown:return
 for arc in arcs:
  if arc.life<=0:arc.op=0;continue
  arc.life-=dt
  arc.rot=SaltlineHudProjection.js_round(rad_to_deg(atan2(arc.src.x-player_pos.x,-(arc.src.z-player_pos.z))+yaw))
  arc.op=SaltlineHudProjection.js_round(clampf(arc.life/.6,0,1)*20)/20.0
 for index in range(feed.size()-1,-1,-1):
  var entry:Dictionary=feed[index];entry.life-=dt
  if entry.life<=0:feed.remove_at(index)
  elif entry.life<.6 and not entry.out:
   entry.out=true;entry.fade_time=0;entry.fade_duration=preload("res://scripts/motion_preference.gd").duration(.5)
