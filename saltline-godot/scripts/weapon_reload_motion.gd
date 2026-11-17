extends RefCounted
# State-bearing portions of original rig reload methods; parts/arms stay separate.
const Math=preload("res://scripts/weapon_motion_math.gd")
const RIFLE={"magout":.4,"swap":.8,"insert":1.15,"short":1.31,"magin":1.44,"regrip":1.54,"atHandle":1.84,"tacBack":1.89,"tacRelease":1.905,"tacBolt":1.93,"back":1.96,"release":2.12,"bolt":2.155,"partial":.32}
const PISTOL={"magout":.18,"swap":.48,"insert":.9,"fingers":1.02,"magin":1.13,"thumb":1.53,"slideRelease":1.575,"slide":1.61}
var a:Dictionary
var events:Array=[]
var arm_impulses=0
var current_gun=""
var event_owner:WeakRef
var event_method:StringName
var parts_motion
var magazine_motion
var reload_hand
var arms

func _init(state:Dictionary,owner:Object=null,method:StringName=&"_reload_event")->void:
 a=state;event_owner=weakref(owner) if owner!=null else null;event_method=method
func window(time:float,start:float,finish:float)->float:
 return 0.0 if time<start or time>=finish else Math.ease((time-start)/(finish-start))
func event(reload:Dictionary,name:String,at:float,extra:Dictionary={})->bool:
 if event_owner!=null:
  var owner=event_owner.get_ref()
  if owner==null or not owner.call(event_method,reload,name,at,extra):return false
 else:
  if reload.t<at or reload.f.get(name,false):return false
  reload.f[name]=1
 var payload={"phase":name,"empty":reload.empty,"weapon":current_gun}
 payload.merge(extra,true);events.append(payload)
 return true
func step(gun:String,reload:Dictionary,time:float)->void:
 current_gun=gun
 var empty=bool(reload.empty)
 if gun=="rifle":
  var t=RIFLE
  if event(reload,"magout",t.magout):a.bump.v-=.25
  if time>=t.swap and not reload.f.get("fresh",false):
   reload.f.fresh=1
   if parts_motion!=null:parts_motion.magazine_fresh(gun)
  if event(reload,"maginsert",t.insert):a.bump.v+=.1;a.kR.v+=.4
  if event(reload,"magin",t.magin):
   a.bump.v+=.8;a.kR.v-=.55;arm_impulses+=1
   if arms!=null:arms.reload_impulse()
   if parts_motion!=null:parts_motion.reload_event(gun,"magin",empty)
  if time>=t.regrip+.025 and not reload.f.get("tug",false):reload.f.tug=1;a.bump.v-=.3
  var back=t.back if empty else t.tacBack;var release=t.release if empty else t.tacRelease;var bolt=t.bolt if empty else t.tacBolt
  if parts_motion!=null:parts_motion.rifle_handle(time,empty)
  if event(reload,"boltback",back,{} if empty else {"partial":true}):
   if parts_motion!=null:parts_motion.reload_event(gun,"boltback",empty)
   a.kZ.v+=.55 if empty else .3;a.bump.v-=.12 if empty else .06
  if event(reload,"bolt",bolt):
   if parts_motion!=null:parts_motion.reload_event(gun,"bolt",empty)
   a.kZ.v-=.85 if empty else .45;a.kP.v-=.9 if empty else .4;a.bump.v-=.14 if empty else .05
  a.antYT=.0045*window(time,t.magout-.14,t.magout)-.002*window(time,t.insert-.1,t.insert)-.006*window(time,t.short,t.magin)
  a.antRT=.022*window(time,t.magout-.14,t.magout)+.05*window(time,t.atHandle-.04,release)
  if magazine_motion!=null:magazine_motion.update(gun,time)
  if reload_hand!=null:reload_hand.update(gun,time,empty)
  var enter=Math.ease(time/.3);var exit=1.0-Math.ease((time-(reload.T-.46))/.4)
  a.reloadW=minf(enter,exit);a.rackW=Math.ease((time-(t.magin+.08))/.28)*exit
 else:
  var t=PISTOL
  if event(reload,"magout",t.magout):a.bump.v+=.1
  if time>=t.swap and not reload.f.get("fresh",false):
   reload.f.fresh=1
   if parts_motion!=null:parts_motion.magazine_fresh(gun)
  if event(reload,"maginsert",t.insert):a.bump.v+=.1;a.kR.v+=.5
  if event(reload,"magin",t.magin):
   a.bump.v+=.85;a.kP.v+=.85;arm_impulses+=1
   if arms!=null:arms.reload_impulse()
  if empty and event(reload,"slide",t.slide):
   if parts_motion!=null:parts_motion.reload_event(gun,"slide",empty)
   a.kZ.v-=.9;a.kP.v-=2.6;a.bump.v-=.12
  a.antRT=.035*window(time,.03,t.magout)-.03*window(time,t.thumb-.08,t.slideRelease)*(1.0 if empty else 0.0)
  a.antYT=-.002*window(time,t.insert-.1,t.insert)-.0065*window(time,t.fingers,t.magin)+.003*window(time,t.thumb-.08,t.slideRelease)*(1.0 if empty else 0.0)
  if magazine_motion!=null:magazine_motion.update(gun,time)
  if reload_hand!=null:reload_hand.update(gun,time,empty)
  if parts_motion!=null:parts_motion.pistol_reload_pose(time,empty)
  a.reloadW=minf(Math.ease(time/.22),1.0-Math.ease((time-(t.magin+.03))/.32))
  a.rackW=Math.ease((time-(t.magin+.05))/.28)*(1.0-Math.ease((time-(t.slide+.04))/.24)) if empty else 0.0
func clear_targets()->void:
 a.reloadW=0.0;a.rackW=0.0;a.antYT=0.0;a.antRT=0.0
