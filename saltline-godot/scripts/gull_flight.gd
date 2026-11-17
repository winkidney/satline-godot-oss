class_name SaltlineGullFlight
extends RefCounted

var state:Dictionary
var coordinator:SaltlineEnemyCoordinator
var physics:SaltlinePhysics
var tuning:Dictionary
var acceleration=Vector3.ZERO
var heading_error=0.0
var horizontal_speed=0.0
var body_y=0.0
var rotor_angles=[0.0,0.0,0.0,0.0]
var injured=false

func _init(actor_state:Dictionary,manager:SaltlineEnemyCoordinator)->void:
 state=actor_state;coordinator=manager;physics=manager.physics;tuning=manager.tuning.gull
 for key in ["pos","vel","home","lastKnown","sensor","fwd","muzzle","avoid"]:
  if state.get(key) is Array:
   var value:Array=state[key];state[key]=Vector3(value[0],value[1],value[2])

func angle_delta(target:float,current:float)->float:
 var delta=fmod(target-current,TAU)
 if delta>PI:delta-=TAU
 elif delta< -PI:delta+=TAU
 return delta

func update(dt:float)->void:
 var player=coordinator.player;var time=coordinator.time;var rng=coordinator.rng
 var sy=sin(state.yaw);var cy=cos(state.yaw)
 state.fwd=Vector3(sy,0,cy);state.sensor=state.pos+Vector3(.27*sy,-.17,.27*cy)
 coordinator.think(state,dt,.4)
 var engaged=state.mode=="engage"
 injured=state.hp<tuning.hp*.5
 var maximum_speed=float(tuning.patrolSpeed);var target=Vector3.ZERO
 if engaged and player!=null:
  maximum_speed=tuning.maxSpeed
  var attacking=state.atk!="idle"
  state.flipT-=dt
  if state.flipT<=0:
   state.flipT=3+rng.randf()*5
   if rng.randf()<.6:state.orbitDir=-state.orbitDir
   state.orbitR=clampf(state.orbitR+(rng.randf()-.5)*6,tuning.rangeMin+1,tuning.rangeMax-2)
  if state.noSeeT>1.5:
   target=state.lastKnown+Vector3(0,state.alt+1,0)
   state.orbitA=atan2(state.pos.z-state.lastKnown.z,state.pos.x-state.lastKnown.x)
  else:
   state.orbitA+=state.orbitDir*(.9 if attacking else 3.6)/state.orbitR*dt
   target=player.pos+Vector3(cos(state.orbitA)*state.orbitR,state.alt,sin(state.orbitA)*state.orbitR)
 elif state.mode=="investigate" or state.mode=="search":
  maximum_speed=5.5;state.orbitA+=.5*dt
  target=state.lastKnown+Vector3(cos(state.orbitA)*4.5,minf(state.alt,5.5),sin(state.orbitA)*4.5)
 else:
  state.orbitA+=.28*dt*state.orbitDir
  target=Vector3(state.home.x+cos(state.orbitA)*state.patrolR,state.alt if state.hoverFixed else state.home.y,state.home.z+sin(state.orbitA)*state.patrolR)
 if target.y>state.ceil:target.y=state.ceil
 if not state.hoverFixed and target.y<2.2:target.y=2.2
 acceleration=Vector3((target.x-state.pos.x)*2.2-state.vel.x*2.4,(target.y-state.pos.y)*5-state.vel.y*3.6,(target.z-state.pos.z)*2.2-state.vel.z*2.4)
 state.feeler=(int(state.feeler)+1)%3
 horizontal_speed=Vector2(state.vel.x,state.vel.z).length()
 if state.feeler==0 and horizontal_speed>.6:
  var direction=Vector3(state.vel.x/horizontal_speed,0,state.vel.z/horizontal_speed)
  var range_limit=2.2+horizontal_speed*.5;var hit=physics.raycast(state.pos,direction,range_limit)
  if not hit.is_empty():
   var strength=1-hit.dist/range_limit;state.avoid=hit.normal*26*strength;state.avoid.y+=9*strength
   if strength>.5:state.orbitDir=-state.orbitDir;state.flipT=2.5
 elif state.feeler==1:
  var hit=physics.raycast(state.pos,Vector3.DOWN,2.4)
  if not hit.is_empty() and not state.hoverFixed:state.avoid.y+=(2.4-hit.dist)*10
 elif state.feeler==2:
  state.ceilT-=dt*3
  if state.ceilT<=0:
   state.ceilT=.35
   var hit=physics.raycast(state.pos,Vector3.UP,4)
   state.ceil=state.pos.y+hit.dist-1.3 if not hit.is_empty() else 1e9
 acceleration+=state.avoid;state.avoid*=exp(-6*dt)
 if injured:
  acceleration.x+=sin(time*7.3+state.phase)*5;acceleration.z+=cos(time*6.1+state.phase)*5;acceleration.y+=sin(time*9.7)*3
 var magnitude=acceleration.length()
 if magnitude>tuning.accel:acceleration*=tuning.accel/magnitude
 state.vel+=acceleration*dt
 var speed=state.vel.length()
 if speed>maximum_speed:state.vel*=maximum_speed/speed
 for axis in 3:
  var value=float(state.vel[axis])
  if absf(value)<.02:continue
  var direction_sign=1 if value>0 else -1;var radius=.35 if axis==1 else .62
  var direction=Vector3.ZERO;direction[axis]=direction_sign
  var hit=physics.raycast(state.pos,direction,absf(value)*dt+radius)
  if not hit.is_empty():
   state.vel[axis]=-value*.25;state.avoid[axis]-=direction_sign*8
   if hit.dist<radius:state.pos[axis]-=direction_sign*(radius-hit.dist)
 state.pos+=state.vel*dt
 if not state.hoverFixed:
  var floor_height=physics.ground_height(state.pos.x,state.pos.z,state.pos.y+.5)+1.1
  if state.pos.y<floor_height:
   state.pos.y=floor_height
   if state.vel.y<0:state.vel.y=0
 var target_yaw=float(state.yaw)
 if (engaged or state.mode=="search" or state.mode=="investigate") and player!=null:
  var look:Vector3=player.pos if engaged and state.noSeeT<1.5 else state.lastKnown
  target_yaw=atan2(look.x-state.pos.x,look.z-state.pos.z)
 elif horizontal_speed>.4:target_yaw=atan2(state.vel.x,state.vel.z)
 heading_error=angle_delta(target_yaw,state.yaw);state.yaw+=clampf(heading_error,-3.2*dt,3.2*dt)
 cy=cos(state.yaw);sy=sin(state.yaw)
 var forward_acceleration=acceleration.x*sy+acceleration.z*cy;var lateral_acceleration=acceleration.x*cy-acceleration.z*sy
 var pitch=clampf(forward_acceleration*.04,-.42,.42);var roll=clampf(-lateral_acceleration*.04,-.42,.42)
 if injured:pitch+=sin(time*11+state.phase)*.1;roll+=cos(time*8.7+state.phase*2)*.13
 var blend=1-exp(-7*dt);state.pitch+=(pitch-state.pitch)*blend;state.roll+=(roll-state.roll)*blend
 body_y=sin(time*2.1+state.phase)*.045+sin(time*3.7+state.phase*1.7)*.018
 state.thr+=(1+clampf(acceleration.y*.03,-.25,.4)+horizontal_speed*.02-state.thr)*blend
 var rotation=41*state.thr*dt
 rotor_angles[0]+=rotation;rotor_angles[1]-=rotation*1.03;rotor_angles[2]-=rotation*.98;rotor_angles[3]+=rotation*1.01
