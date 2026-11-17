class_name SaltlineGullScanLight
extends RefCounted

var physics:SaltlinePhysics
var pool:SaltlineLightPool
var slot:Dictionary={}
var tried_acquire=false
var timer=0.0
var target=Vector3.ZERO
var hit_gain=0.0
var position=Vector3.ZERO
var energy=0.0
var selected_id=0
var maximum_energy=0.0
var samples=0
var hit_samples=0

func _init(collision:SaltlinePhysics,lights:SaltlineLightPool=null)->void:physics=collision;pool=lights

func update(dt:float,actors:Array,camera_position:Variant=null)->void:
 if not tried_acquire:
  tried_acquire=true
  if pool!=null:
   slot=pool.acquire()
   if not slot.is_empty():slot.light.light_color=Color(1,.9,.75).linear_to_srgb();slot.light.omni_range=9;position=slot.light.global_position;energy=float(slot.source_intensity)
 if pool!=null and slot.is_empty():return
 var selected:Variant=null;var nearest=3600.0
 for actor in actors:
  var state:Dictionary=actor.state
  if state.type!="gull" or not state.alive:continue
  var distance=state.pos.distance_squared_to(camera_position) if camera_position!=null else 0.0
  if distance<nearest:nearest=distance;selected=state
 var desired=0.0;selected_id=0
 if selected!=null:
  selected_id=int(selected.id);timer-=dt
  if timer<=0:
   timer=.1;samples+=1
   var yaw=selected.yaw+selected.gy;var cp=cos(selected.gp)
   var direction=Vector3(sin(yaw)*cp,-sin(selected.gp),cos(yaw)*cp).normalized()
   var hit=physics.raycast(selected.sensor,direction,14)
   target=selected.sensor+direction*((hit.dist if not hit.is_empty() else 8)-.6);hit_gain=1 if not hit.is_empty() else .3
   if not hit.is_empty():hit_samples+=1
  desired=26*hit_gain;position=position.lerp(target,1-exp(-12*dt))
 energy+=(desired-energy)*(1-exp(-8*dt));maximum_energy=maxf(maximum_energy,energy)
 if not slot.is_empty():slot.light.global_position=position;pool.set_energy(slot,energy)

func clear()->void:
 energy=0
 if not slot.is_empty():pool.set_energy(slot,0.0)

func dispose()->void:
 if pool!=null and not slot.is_empty():pool.release(slot);slot={}
