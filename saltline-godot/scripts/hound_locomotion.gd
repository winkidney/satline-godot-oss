class_name SaltlineHoundLocomotion
extends RefCounted

signal reposition_requested
var state:Dictionary
var navigation:SaltlineNavigation
var physics:SaltlinePhysics
var tuning:Dictionary
var rng:SaltlineSourceRng
var replans=0

func _init(actor_state:Dictionary,nav:SaltlineNavigation,settings:Dictionary,random_stream:SaltlineSourceRng)->void:
 state=actor_state;navigation=nav;physics=nav.physics;tuning=settings;rng=random_stream
 state.goal=Vector3.ZERO;state.path=null;state.wp=0;state.hasGoal=false;state.planT=0;state.stuckT=0;state.feelT=0;state.blocked=false

func angle_delta(target:float,current:float)->float:
 var delta=fmod(target-current,TAU)
 if delta>PI:delta-=TAU
 elif delta< -PI:delta+=TAU
 return delta

func set_goal(target:Vector3,force:bool=false)->void:
 if not force and state.hasGoal and state.goal.distance_squared_to(target)<.25:return
 state.goal=target;state.hasGoal=true;state.planT=0;state.stuckT=0

func replan()->void:
 state.planT=tuning.replan+rng.randf()*.15
 var path=navigation.find_path(state.pos,state.goal)
 state.path=path if path!=null and not path.is_empty() else null
 state.wp=0;replans+=1
 if state.path!=null and state.path.size()>1 and state.path[0].distance_squared_to(state.pos)<.36:state.wp=1

func follow_goal(dt:float,speed:float)->bool:
 if not state.hasGoal:state.maxSpeed=0;return true
 state.planT-=dt
 if state.planT<=0:replan()
 var target:Vector3=state.goal
 if state.path!=null:
  while state.wp<state.path.size()-1 and Vector2(state.path[state.wp].x-state.pos.x,state.path[state.wp].z-state.pos.z).length()<.55:state.wp+=1
  target=state.path[mini(state.wp,state.path.size()-1)]
 var distance=Vector2(state.goal.x-state.pos.x,state.goal.z-state.pos.z).length()
 if distance<.45:state.hasGoal=false;state.maxSpeed=0;return true
 state.wantYaw=atan2(target.x-state.pos.x,target.z-state.pos.z)
 var error=absf(angle_delta(state.wantYaw,state.yaw))
 state.maxSpeed=0 if error>1.1 else minf(speed*(1-error*.5),.4+distance*2.6)
 return false

func move(dt:float,neighbors:Array=[],player:Variant=null,lunge:bool=false)->void:
 var desired=clampf(angle_delta(state.wantYaw,state.yaw)*6,-tuning.turnRate,tuning.turnRate)*(2 if lunge else 1)
 state.yawRate+=(desired-state.yawRate)*(1-exp(-10*dt));state.yaw+=state.yawRate*dt
 var acceleration=tuning.accel if state.maxSpeed>state.speed else -tuning.accel*1.4
 state.prevSpeed=state.speed
 if not lunge:state.speed=clampf(state.speed+acceleration*dt,0,maxf(state.maxSpeed,0))
 if not lunge and acceleration<0 and state.speed<state.maxSpeed:state.speed=state.maxSpeed
 var sx=sin(state.yaw);var sz=cos(state.yaw)
 for other in neighbors:
  if other.id==state.id or other.type!="hound" or not other.active:continue
  var delta=Vector2(state.pos.x-other.pos.x,state.pos.z-other.pos.z);var distance=delta.length()
  if distance<1.7 and distance>.001:
   var amount=(1.7-distance)*2.2/distance;state.push.x+=delta.x*amount*dt*6;state.push.z+=delta.y*amount*dt*6
 if player!=null and not lunge:
  var delta=Vector2(state.pos.x-player.pos.x,state.pos.z-player.pos.z);var distance=delta.length()
  if distance<1.25 and distance>.001:
   var amount=(1.25-distance)*3/distance;state.push.x+=delta.x*amount*dt*6;state.push.z+=delta.y*amount*dt*6
 state.push*=exp(-5*dt)
 var x=state.pos.x+(sx*state.speed+state.push.x)*dt;var z=state.pos.z+(sz*state.speed+state.push.z)*dt
 state.feelT-=dt
 if state.feelT<=0 and state.speed>.3:
  state.feelT=.12;state.blocked=not physics.raycast(state.pos+Vector3(0,.55,0),Vector3(sx,0,sz),.75+state.speed*.12).is_empty()
 elif state.speed<=.3:state.blocked=false
 if not navigation.is_walkable(x,z) or (state.blocked and (not lunge or state.esT<.3)):
  if state.blocked:
   x=state.pos.x+state.push.x*dt;z=state.pos.z+state.push.z*dt;state.yawRate+=(1 if state.phase>3.14 else -1)*4*dt
  elif navigation.is_walkable(x,state.pos.z):z=state.pos.z
  elif navigation.is_walkable(state.pos.x,z):x=state.pos.x
  else:x=state.pos.x;z=state.pos.z
  state.speed*=.6;state.stuckT+=dt
  if state.stuckT>.5:
   state.stuckT=0;state.planT=0
   if state.mode=="engage" and state.es=="move":reposition_requested.emit()
   elif state.mode=="patrol":state.hasGoal=false
 state.pos.x=x;state.pos.z=z
 state.pos.y+=(physics.ground_height(x,z,state.pos.y+.6)-state.pos.y)*(1-exp(-12*dt))
