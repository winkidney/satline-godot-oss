class_name SaltlineGullLife
extends RefCounted

signal hit_received(point:Vector3,part:String)
signal killed
signal rotor_lost(index:int)
signal pose_requested
signal retired
signal effect_requested(kind:String,position:Vector3,options:Dictionary)
signal explosion_requested(position:Vector3,radius:float,damage:float)
var state:Dictionary
var flight:SaltlineGullFlight
var coordinator:SaltlineEnemyCoordinator
const ROTORS=[Vector3(.33,.05,.3),Vector3(-.33,.05,.3),Vector3(.33,.05,-.3),Vector3(-.33,.05,-.3)]

func _init(movement:SaltlineGullFlight)->void:flight=movement;state=flight.state;coordinator=flight.coordinator

func damage(amount:float,point:Vector3,direction:Variant=null,part:String="body")->bool:
 if not state.alive:return false
 state.hp-=amount;hit_received.emit(point,part)
 if direction!=null:
  state.vel+=direction*minf(3,amount*.09);state.roll+=(coordinator.rng.randf()-.5)*.5;state.pitch+=(coordinator.rng.randf()-.5)*.4
 coordinator.provoke(state)
 if state.hp<=0:die(direction);return true
 return false

func die(direction:Variant=null)->void:
 var rng=coordinator.rng
 state.alive=false;coordinator.release_token(state);state.dieT=0;state.lostRotor=int(floor(rng.randf()*4));rotor_lost.emit(state.lostRotor)
 var position:Vector3=state.pos+ROTORS[int(state.lostRotor)].rotated(Vector3.UP,state.yaw)
 effect_requested.emit("sparks",position,{"normal":Vector3.UP,"count":14});effect_requested.emit("debris",position,{"count":3});effect_requested.emit("smoke",position,{"size":.5,"life":1})
 state.spin=(-1 if rng.randf()<.5 else 1)*(5+rng.randf()*3);state.vel.y+=1.5
 if direction!=null:state.vel+=direction*2.5
 killed.emit()

func update(dt:float)->void:
 state.dieT+=dt;state.vel.y-=9.5*dt;state.vel.x*=1-.4*dt;state.vel.z*=1-.4*dt
 state.spin+=signf(state.spin)*7*dt;state.yaw+=state.spin*dt;state.roll+=state.spin*.35*dt;state.pitch+=.9*dt
 var speed=state.vel.length();var distance=speed*dt;var crashed=state.dieT>5 or state.pos.y< -3
 if not crashed and speed>.01:
  var hit=flight.physics.raycast(state.pos,state.vel/speed,distance+.3)
  if not hit.is_empty():state.pos=hit.point+hit.normal*.2;crashed=true
 if not crashed:state.pos+=state.vel*dt
 for i in 4:
  if i!=state.lostRotor:flight.rotor_angles[i]+=(1 if i%3==0 else -1)*30*maxf(.2,1-state.dieT*.5)*dt
 pose_requested.emit()
 state.smokeT-=dt
 if state.smokeT<=0:
  state.smokeT=.045;effect_requested.emit("smoke",state.pos,{"size":.45,"life":1.3,"color":1381914,"rise":.6})
  if coordinator.rng.randf()<.5:
   var direction=Vector3(coordinator.rng.randf()-.5,coordinator.rng.randf(),coordinator.rng.randf()-.5).normalized()
   effect_requested.emit("sparks",state.pos,{"normal":direction,"count":3})
 if crashed:
  effect_requested.emit("explosion",state.pos,{"size":1.2});explosion_requested.emit(state.pos,flight.tuning.explodeRadius,flight.tuning.explodeDamage);retired.emit()
