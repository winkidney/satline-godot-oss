class_name SaltlineHoundLife
extends RefCounted

signal hit_received(point:Vector3,part:String)
signal killed
signal retired
signal pose_requested(dt:float)
signal lens_requested(color:Vector3)
signal effect_requested(kind:String,position:Vector3,options:Dictionary)
var state:Dictionary
var coordinator:SaltlineEnemyCoordinator
var rng:SaltlineSourceRng

func _init(actor_state:Dictionary,manager:SaltlineEnemyCoordinator)->void:
 state=actor_state;coordinator=manager;rng=manager.rng

func damage(amount:float,point:Vector3,direction:Variant=null,part:String="body")->bool:
 if not state.alive:return false
 state.hp-=amount;hit_received.emit(point,part)
 if direction!=null:
  var cy=cos(state.yaw);var sy=sin(state.yaw);var strength=minf(1.6,amount/28)
  var longitudinal=direction.x*sy+direction.z*cy;var lateral=direction.x*cy-direction.z*sy
  state.sL.v+=lateral*1.4*strength;state.sR.v-=lateral*3.2*strength
  state.sP.v+=longitudinal*2.4*strength*(1.6 if part=="weak" else 1);state.sY.v-=.5*strength
 coordinator.provoke(state)
 if state.hp<=0:die();return true
 return false

func die()->void:
 state.alive=false;coordinator.release_token(state);state.dieT=0;state.vy=0;state.es="move"
 state.dieRoll=(-1 if rng.randf()<.5 else 1)*(.25+rng.randf()*.3)
 state.diePitch=(rng.randf()-.5)*.25;state.sR.v+=state.dieRoll*3;state.sP.v+=(rng.randf()-.5)*2
 for i in 4:
  var foot:Dictionary=state.feet[i]
  if state.sw>=0:foot.p.y=state.pos.y
  var side=SaltlineHoundPose.SIDES[i]*(.16+rng.randf()*.2)
  var fore=SaltlineHoundPose.FORE[i]*(.05+rng.randf()*.22)+(rng.randf()-.5)*.1
  foot.slide=Vector3(side*cos(state.yaw)+fore*sin(state.yaw),0,-side*sin(state.yaw)+fore*cos(state.yaw))
 state.sw=-1;state.speed*=.3
 effect_requested.emit("sparks",state.headPos,{"normal":Vector3.UP,"count":16})
 effect_requested.emit("debris",state.headPos,{"count":4});killed.emit()

func _spring(key:String,target:float,stiffness:float,damping:float,dt:float)->void:
 var spring:Dictionary=state[key];spring.v+=((target-spring.x)*stiffness-spring.v*damping)*dt;spring.x+=spring.v*dt

func update(dt:float)->void:
 if state.sink>0:
  state.sink+=dt;state.pos.y-=.22*dt
  if state.sink>3.2:retired.emit()
  return
 state.dieT+=dt
 var time:float=state.dieT
 if time<2.2:
  var floor_offset=.215-.72
  state.vy-=9.8*dt*(.3 if time<.12 else 1);state.sY.x+=state.vy*dt
  if state.sY.x<floor_offset:
   state.sY.x=floor_offset
   if state.vy< -1.2:effect_requested.emit("crash",state.pos,{"speed":5})
   state.vy=-state.vy*.22
  _spring("sP",state.diePitch,60,9,dt);_spring("sR",state.dieRoll,60,9,dt);_spring("sL",0,40,8,dt)
  var decay=exp(-3.2*dt)
  for foot in state.feet:foot.p.x+=foot.slide.x*(1-decay);foot.p.z+=foot.slide.z*(1-decay);foot.slide*=decay
  state.pos.x+=sin(state.yaw)*state.speed*dt;state.pos.z+=cos(state.yaw)*state.speed*dt;state.speed*=exp(-5*dt)
  state.hpitch+=(.55-state.hpitch)*(1-exp(-5*dt));state.hyaw+=(state.dieRoll-state.hyaw)*(1-exp(-3*dt));state.tpitch+=(.3-state.tpitch)*(1-exp(-4*dt))
  var intensity=(1-time/1.2 if sin(time*60)>.2 else .05) if time<1.2 else .02
  lens_requested.emit(Vector3(6*intensity+.05,.6*intensity+.01,.2*intensity));pose_requested.emit(dt)
 if time<6.5:
  state.smokeT-=dt
  if state.smokeT<=0:
   state.smokeT=.09 if time<2 else .2
   var position=Vector3(state.pos.x+(rng.randf()-.5)*.4,state.pos.y+.42,state.pos.z+(rng.randf()-.5)*.4)
   effect_requested.emit("smoke",position,{"size":.5+rng.randf()*.3,"life":1.8,"color":1513499,"rise":1.1})
   if time<4 and rng.randf()<.55:
    var direction=Vector3(rng.randf()-.5,1,rng.randf()-.5).normalized()
    effect_requested.emit("sparks",position,{"normal":direction,"count":8 if time<1 else 3})
   if time<3.5 and rng.randf()<.4:effect_requested.emit("smoke",position,{"size":.22,"life":.45,"color":16742946,"rise":1.6})
 elif not state.wreck:state.wreck=true
