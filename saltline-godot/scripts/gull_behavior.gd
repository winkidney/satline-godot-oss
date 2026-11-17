class_name SaltlineGullBehavior
extends RefCounted

signal telegraph(duration:float)
signal bolt_requested(origin:Vector3,direction:Vector3)
signal effect_requested(kind:String,position:Vector3,options:Dictionary)
var state:Dictionary
var flight:SaltlineGullFlight
var coordinator:SaltlineEnemyCoordinator
var lens_color=Vector3.ZERO
var strobe_rg=1.0
var strobe_w=1.0
var gun_pitch=0.0

func _init(movement:SaltlineGullFlight)->void:
 flight=movement;state=flight.state;coordinator=flight.coordinator

# Original v tail. Movement/body/rotors have already updated for this frame.
func update(dt:float)->void:
 var time=coordinator.time;var player=coordinator.player;var rng=coordinator.rng;var tuning=flight.tuning
 var engaged=state.mode=="engage";var injured=flight.injured
 var phase=fmod(time*.9+state.phase*.1,1)
 strobe_rg=1 if phase<.05 or (phase>.13 and phase<.18) else .0001
 strobe_w=1 if phase>.5 and phase<.56 else .0001
 var target=Vector3.ZERO
 if engaged and player!=null:target=player.pos+Vector3(0,1.1,0)
 elif state.mode!="patrol":
  state.sweep+=dt;target=state.lastKnown+Vector3(sin(state.sweep*.9)*3,0,cos(state.sweep*.7)*3)
 else:
  state.sweep+=dt
  var direction=state.yaw+sin(state.sweep*.5+state.phase)*.9
  target=state.pos+Vector3(sin(direction)*5,-1.6 if state.hoverFixed else -5,cos(direction)*5)
 var offset:Vector3=target-state.sensor;var cy=cos(state.yaw);var sy=sin(state.yaw)
 var x=offset.x*cy-offset.z*sy;var z=offset.x*sy+offset.z*cy
 var target_yaw=atan2(x,z);var target_pitch=clampf(atan2(-offset.y,Vector2(x,z).length()),-.5,1.5)
 var blend=1-exp(-9*dt);state.gy+=flight.angle_delta(target_yaw,state.gy)*blend;state.gp+=(target_pitch-state.gp)*blend
 gun_pitch=clampf(state.gp,-.2,1.3)-state.pitch
 var base=Vector3(14,1,.35) if engaged else Vector3(8,4,.7)
 var gain=1+state.flare*3.2+(0 if engaged else sin(time*3+state.phase)*.15)
 for i in 3:state.lensC[i]+=(base[i]-state.lensC[i])*(1-exp(-8*dt))
 lens_color=Vector3(state.lensC[0],state.lensC[1],state.lensC[2])*gain
 state.flare=maxf(0,state.flare-dt*1.5)
 state.muzzle=state.pos+Vector3(.17*sy,-.12,.17*cy);state.cool-=dt
 if state.atk=="idle":
  if engaged and state.los and state.cool<=0 and player!=null and player.alive and absf(flight.heading_error)<.35 and state.pos.distance_to(player.pos)<tuning.fireRange and coordinator.request_token(state):
   state.atk="tele";state.atkT=tuning.telegraph;telegraph.emit(tuning.telegraph)
 elif state.atk=="tele":
  state.atkT-=dt;state.flare=minf(1,state.flare+dt*4.5)
  if engaged:
   if state.atkT<=0:state.atk="burst";state.shots=tuning.burst;state.atkT=0;state.lead=.2+rng.randf()*.65
  else:state.atk="idle";coordinator.release_token(state)
 elif state.atk=="burst":
  state.atkT-=dt;state.flare=1
  if state.atkT<=0:
   state.atkT=tuning.burstGap;state.shots-=1
   if player!=null:
    var distance=state.muzzle.distance_to(player.pos);var travel=distance/tuning.boltSpeed
    var velocity:Vector3=player.velocity
    target=Vector3(player.pos.x+velocity.x*travel*state.lead,player.pos.y+1.05,player.pos.z+velocity.z*travel*state.lead)
    var direction:Vector3=(target-state.muzzle).normalized()
    var spread=(tuning.spreadFar+(tuning.spreadNear-tuning.spreadFar)*state.exposure)*(1+float(coordinator.get_meta("player_speed",0))*.45)*(1.5 if injured else 1)
    direction.x+=(rng.randf()-.5)*2*spread;direction.y+=(rng.randf()-.5)*2*spread;direction.z+=(rng.randf()-.5)*2*spread;direction=direction.normalized()
    bolt_requested.emit(state.muzzle,direction);state.vel-=direction*.35
   if state.shots<=0:
    state.atk="idle";state.cool=tuning.cooldown[0]+rng.randf()*(tuning.cooldown[1]-tuning.cooldown[0]);coordinator.release_token(state)
 if injured:
  state.smokeT-=dt
  if state.smokeT<=0:
   state.smokeT=.16;effect_requested.emit("smoke",state.pos,{"size":.3,"life":1.1,"color":2500652,"rise":.8})
   if rng.randf()<.15:effect_requested.emit("sparks",state.pos,{"normal":Vector3.DOWN,"count":2})
