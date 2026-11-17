class_name SaltlinePlayer
extends RefCounted

var physics:SaltlinePhysics
var tuning:Dictionary
var pos:Vector3
var velocity=Vector3.ZERO
var yaw:float
var pitch=0.0
var on_ground=true
var crouching=false
var sprinting=false
var ads=0.0
var speed=0.0
signal hit(amount:float,from_position:Variant)
signal died
signal motion_event(kind:String,payload:Dictionary)
var ground_surface="concrete"
var surface_resolver:Callable
var health=100.0
var max_health=100.0
var alive=true
var invulnerable=false
var enabled=true
var hurt_pulse=0.0
var low_health=0.0
var since_hit=99.0
var death_time=0.0
var forward=Vector3.FORWARD
var eye=Vector3.ZERO
var eye_height=1.68
var stride_phase=0.0
var bob_strength=0.0
var bob_x=0.0
var bob_y=0.0
var roll=0.0
var coyote=0.0
var jump_buffer=0.0
var air_time=0.0
var fall_speed=0.0
var dip=0.0
var dip_velocity=0.0
var safe_pos:Vector3
var base_fov=74.0
var fov=74.0
var recoil_pitch=0.0
var recoil_yaw=0.0
var recoil_applied_pitch=0.0
var recoil_applied_yaw=0.0
var recoil_hold=0.0
var shake=0.0
var clock=0.0

func _init(data:Dictionary,collision:SaltlinePhysics)->void:
 physics=collision;tuning=data.tuning
 pos=Vector3(data.pos[0],data.pos[1],data.pos[2]);safe_pos=pos;yaw=data.yaw
 eye=pos+Vector3(0,1.68,0)

func damp(value:float,target:float,rate:float,dt:float)->float:
 return lerpf(value,target,1-exp(-rate*dt))

func look(relative:Vector2)->void:
 look_normalized(relative.x*.0021,relative.y*.0021)

func look_normalized(dx:float,dy:float)->void:
 if not alive or not enabled:return
 var scale=lerpf(1,tuning.adsLook,ads)
 yaw-=dx*scale;pitch=clampf(pitch-dy*scale,-tuning.pitchLimit,tuning.pitchLimit)
 if absf(yaw)>PI*4:yaw=fmod(yaw,PI*2)

func event_surface()->String:
 return str(surface_resolver.call(pos,ground_surface)) if surface_resolver.is_valid() else ground_surface

func update(dt:float,input:Dictionary,camera:Camera3D)->void:
 if not enabled:
  input=input.duplicate();input.move=Vector2.ZERO;input.sprint=false;input.crouch=false;input.fire=false;input.jump=false;input.ads=false
 ads=float(input.ads_value) if input.has("ads_value") else damp(ads,1.0 if input.ads else 0.0,14,dt)
 if not alive:
  _dead_update(dt,camera);return
 if input.crouch:crouching=true
 elif crouching and physics.can_stand(pos,tuning.crouchHeight,tuning.standHeight):crouching=false
 var move:Vector2=input.move
 var moving=move.length_squared()>.01
 var sprint=input.sprint and move.y>.55 and absf(move.x)<.6 and not crouching and ads<.35 and not input.fire
 sprinting=(sprint and on_ground and speed>tuning.walk*.6) or (sprint and not on_ground and sprinting)
 var pace=float(tuning.crouch if crouching else tuning.sprint if sprint else tuning.walk)
 pace=lerpf(pace,minf(pace,tuning.ads),ads)
 if move.y<0:pace*=lerpf(1,.82,-move.y)
 var sy=sin(yaw);var cy=cos(yaw)
 var target=Vector2(move.x*cy-move.y*sy,-move.x*sy-move.y*cy)*pace
 var acceleration=float((tuning.accelGround if moving else tuning.decelGround) if on_ground else (tuning.accelAir if moving else .6))
 var horizontal=Vector2(velocity.x,velocity.z).move_toward(target,acceleration*dt)
 velocity.x=horizontal.x;velocity.z=horizontal.y
 coyote=tuning.coyote if on_ground else maxf(0,coyote-dt)
 jump_buffer=tuning.jumpBuffer if input.jump else maxf(0,jump_buffer-dt)
 var previous_ground=on_ground
 if jump_buffer>0 and coyote>0 and (not crouching or physics.can_stand(pos,tuning.crouchHeight,tuning.standHeight)):
  velocity.y=sqrt(2*tuning.gravity*tuning.jumpApex);jump_buffer=0;coyote=0;on_ground=false;crouching=false
  motion_event.emit("jump",{"pos":pos})
 velocity.y=maxf(-40,velocity.y-tuning.gravity*dt*.5)
 var impact=velocity.y
 var result=physics.move_capsule(pos,velocity,dt,tuning.crouchHeight if crouching else tuning.standHeight,previous_ground)
 pos=result.position;velocity=result.velocity;on_ground=result.on_ground
 if result.get("surface","")!="":ground_surface=str(result.surface)
 if not on_ground:velocity.y-=tuning.gravity*dt*.5
 var lo=physics.bounds.min;var hi=physics.bounds.max
 pos.x=clampf(pos.x,lo[0]+.4,hi[0]-.4);pos.z=clampf(pos.z,lo[2]+.4,hi[2]-.4)
 if on_ground:
  if not previous_ground and air_time>.12:
   var force=maxf(0,maxf(-impact,fall_speed));dip_velocity-=minf(force*tuning.landDip,3.2)
   if force>7.5:shake=minf(1,shake+minf(.5,(force-7.5)*.06))
   motion_event.emit("land",{"speed":force,"surface":event_surface(),"pos":pos})
   if force>13:damage((force-13)*7,null)
   stride_phase=.35
  air_time=0;fall_speed=0
  if pos.x<=28.8 and pos.y>-.5:safe_pos=pos
 else:air_time+=dt;fall_speed=maxf(fall_speed,-velocity.y)
 if pos.y< -3.8:
  pos=safe_pos;velocity=Vector3.ZERO;on_ground=true;shake=.6;yaw+=PI;damage(12,null)
  motion_event.emit("rescued",{})
 update_vitals(dt)
 speed=Vector2(velocity.x,velocity.z).length()
 var stride=float(tuning.stride.crouch if crouching else tuning.stride.sprint if sprinting else tuning.stride.walk)
 if on_ground and speed>.5:
  var previous_phase=stride_phase
  stride_phase+=speed*dt/stride
  if floor(stride_phase)>floor(previous_phase):motion_event.emit("step",{"surface":event_surface(),"sprint":sprinting,"pos":pos})
 elif on_ground:stride_phase=damp(stride_phase,floor(stride_phase+.5),8,dt)
 var amplitude=clampf(speed/tuning.walk,0,1)*(tuning.bobSprint if sprinting else 1)*lerpf(1,tuning.bobAds,ads)*(.7 if crouching else 1) if on_ground else 0.0
 bob_strength=damp(bob_strength,amplitude,9,dt)
 bob_y=-cos(stride_phase*TAU)*tuning.bobY*bob_strength
 bob_x=sin(stride_phase*PI)*tuning.bobX*bob_strength
 roll=damp(roll,-(velocity.x*cy-velocity.z*sy)/tuning.sprint*tuning.rollStrafe*lerpf(1,.4,ads),8,dt)
 eye_height=damp(eye_height,1.05 if crouching else 1.68,tuning.eyeRate,dt)
 dip_velocity+=(-dip*150-dip_velocity*17)*dt;dip=clampf(dip+dip_velocity*dt,-tuning.landDipMax,.05)
 camera.position=pos+Vector3(bob_x*cy,eye_height+bob_y+dip,-bob_x*sy)
 eye=camera.position
 recoil_hold-=dt
 if recoil_hold<=0:
  recoil_pitch=damp(recoil_pitch,0,tuning.recoilRecover,dt);recoil_yaw=damp(recoil_yaw,0,tuning.recoilRecover,dt)
 recoil_applied_pitch=damp(recoil_applied_pitch,recoil_pitch,tuning.recoilApply,dt);recoil_applied_yaw=damp(recoil_applied_yaw,recoil_yaw,tuning.recoilApply,dt)
 shake=maxf(0,shake-tuning.shakeDecay*dt);clock+=dt
 forward=-Basis.from_euler(Vector3(clampf(pitch+recoil_applied_pitch,-1.55,1.55),yaw+recoil_applied_yaw,0),EULER_ORDER_YXZ).z
 var trauma=shake*shake
 var shake_pitch=trauma*tuning.shakePitch*(sin(clock*43.1)+.6*sin(clock*71.7+1.3))
 var shake_yaw=trauma*tuning.shakeYaw*(sin(clock*37.3+2.1)+.6*sin(clock*83.9))
 var shake_roll=trauma*tuning.shakeRoll*(sin(clock*29.7+.7)+.5*sin(clock*61.3+4))
 camera.rotation_order=EULER_ORDER_YXZ;camera.rotation=Vector3(clampf(pitch+recoil_applied_pitch,-1.55,1.55)+dip*.12+shake_pitch,yaw+recoil_applied_yaw+shake_yaw,roll+bob_x*.35+shake_roll)
 var target_fov=lerpf(base_fov+(tuning.fovSprint if sprinting else 0),tuning.fovAds,ads)
 fov=damp(fov,target_fov,30 if ads>.02 and ads<.98 else 7,dt)
 if absf(camera.fov-fov)>.01:camera.fov=fov

func add_recoil(vertical:float,horizontal:float)->void:
 pitch=clampf(pitch+vertical*tuning.recoilKeep,-tuning.pitchLimit,tuning.pitchLimit);yaw+=horizontal*tuning.recoilKeep
 recoil_pitch=clampf(recoil_pitch+vertical*(1-tuning.recoilKeep),-.3,.3)
 recoil_yaw=clampf(recoil_yaw+horizontal*(1-tuning.recoilKeep),-.2,.2);recoil_hold=tuning.recoilHold

func add_shake(amount:float=.3)->void:shake=minf(1,shake+amount)

func damage(amount:float,from_position:Variant=null)->void:
 if not alive or invulnerable or not amount>0:return
 health=maxf(0,health-amount);since_hit=0;hurt_pulse=minf(1,hurt_pulse+.35+amount/40)
 shake=minf(1,shake+.22+amount/70);hit.emit(amount,from_position)
 if health<=0:alive=false;death_time=0;sprinting=false;died.emit()

func heal(amount:float)->void:
 if alive:health=minf(max_health,health+amount)

func update_vitals(dt:float)->void:
 if alive:
  since_hit+=dt
  if since_hit>tuning.regenDelay and health<max_health:health=minf(max_health,health+tuning.regenRate*dt)
 hurt_pulse=maxf(0,hurt_pulse-dt*1.9)
 var target=smoothstep(.55,.12,health/max_health) if alive else 1.0
 low_health=damp(low_health,target,4,dt)

func _dead_update(dt:float,camera:Camera3D)->void:
 death_time+=dt
 velocity.x=damp(velocity.x,0,5,dt);velocity.z=damp(velocity.z,0,5,dt);velocity.y-=tuning.gravity*dt
 var result=physics.move_capsule(pos,velocity,dt,.6,on_ground)
 pos=result.position;velocity=result.velocity;on_ground=result.on_ground
 if pos.y< -2.6:pos.y=-2.6;velocity.y=0
 speed=0;sprinting=false;bob_strength=damp(bob_strength,0,10,dt);bob_x*=.9;bob_y*=.9
 var progress=smoothstep(0,.85,death_time);var squared=progress*progress
 eye_height=damp(eye_height,lerpf(1.68,.22,squared),18,dt)
 dip_velocity+=(-dip*150-dip_velocity*17)*dt;dip=clampf(dip+dip_velocity*dt,-tuning.landDipMax,.05)
 recoil_hold-=dt
 if recoil_hold<=0:recoil_pitch=damp(recoil_pitch,0,tuning.recoilRecover,dt);recoil_yaw=damp(recoil_yaw,0,tuning.recoilRecover,dt)
 recoil_applied_pitch=damp(recoil_applied_pitch,recoil_pitch,tuning.recoilApply,dt);recoil_applied_yaw=damp(recoil_applied_yaw,recoil_yaw,tuning.recoilApply,dt)
 shake=maxf(0,shake-tuning.shakeDecay*dt);clock+=dt
 eye=pos+Vector3(bob_x*cos(yaw),eye_height+bob_y+dip,-bob_x*sin(yaw));camera.position=eye
 forward=-Basis.from_euler(Vector3(clampf(pitch+recoil_applied_pitch,-1.55,1.55),yaw+recoil_applied_yaw,0),EULER_ORDER_YXZ).z
 var trauma=shake*shake
 camera.rotation_order=EULER_ORDER_YXZ
 camera.rotation=Vector3(clampf(pitch+recoil_applied_pitch,-1.55,1.55)-.25*progress+.12*sin(progress*PI)+dip*.12+trauma*tuning.shakePitch*(sin(clock*43.1)+.6*sin(clock*71.7+1.3)),yaw+recoil_applied_yaw+trauma*tuning.shakeYaw*(sin(clock*37.3+2.1)+.6*sin(clock*83.9)),roll+1.15*squared+bob_x*.35+trauma*tuning.shakeRoll*(sin(clock*29.7+.7)+.5*sin(clock*61.3+4)))
 var target_fov=lerpf(base_fov,tuning.fovAds,ads)
 fov=damp(fov,target_fov,30 if ads>.02 and ads<.98 else 7,dt)
 if absf(camera.fov-fov)>.01:camera.fov=fov
 update_vitals(dt)

func reset(start:Dictionary,view:Camera3D=null)->void:
 var position=start.pos
 pos=position if position is Vector3 else Vector3(position[0],position[1],position[2]);yaw=float(start.get("yaw",0));pitch=0;velocity=Vector3.ZERO
 health=max_health;alive=true;on_ground=true;sprinting=false;crouching=false;invulnerable=false;speed=0;eye_height=1.68
 stride_phase=0;bob_strength=0;bob_x=0;bob_y=0;roll=0;coyote=0;jump_buffer=0;air_time=0;fall_speed=0;dip=0;dip_velocity=0
 recoil_pitch=0;recoil_yaw=0;recoil_applied_pitch=0;recoil_applied_yaw=0;recoil_hold=0;shake=0;since_hit=99;hurt_pulse=0;low_health=0;death_time=0;safe_pos=pos
 eye=pos+Vector3(0,1.68,0);forward=-(Basis(Vector3.UP,yaw).z);fov=lerpf(base_fov,tuning.fovAds,ads)
 if view!=null:view.global_position=eye;view.rotation_order=EULER_ORDER_YXZ;view.rotation=Vector3(0,yaw,0)
 if view!=null and absf(view.fov-fov)>.01:view.fov=fov
 # Source reset preserves enabled, ADS and its global shake clock.

func set_fov(value:float)->void:base_fov=clampf(value if value!=0 else 74,55,100)
