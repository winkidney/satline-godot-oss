class_name SaltlineHoundPose
extends RefCounted

signal footstep(position:Vector3,speed:float)

const SIDES=[1,-1,1,-1]
const FORE=[1,1,-1,-1]
const FOOT_Z=[.37,.37,-.42,-.42]
const LEGS=["FL","FR","RL","RR"]
const PAIRS=[[0,3],[1,2]]
var scene:SaltlineSourceScene
var physics:SaltlinePhysics
var state:Dictionary
var bones:Dictionary
var steps=0

func _init(source:SaltlineSourceScene,record:Dictionary,collision:SaltlinePhysics)->void:
 scene=source;physics=collision;state=record.duplicate(true);bones=record.rig.bones
 for key in ["pos","push","headPos"]:
  var v:Array=record[key];state[key]=Vector3(v[0],v[1],v[2])
 for foot in state.feet:
  for key in ["p","from","to","slide"]:
   var v:Array=foot[key];foot[key]=Vector3(v[0],v[1],v[2])

func nominal_foot(index:int,x:float,z:float,yaw:float)->Vector3:
 var side=SIDES[index]*.275;var forward=FOOT_Z[index]
 return Vector3(x+side*cos(yaw)+forward*sin(yaw),0,z-side*sin(yaw)+forward*cos(yaw))

func reset(position:Vector3,yaw:float,update_pose:bool=true)->void:
 state.pos=position;state.yaw=yaw;state.speed=0;state.prevSpeed=0;state.yawRate=0;state.push=Vector3.ZERO
 state.sw=-1;state.idleT=0;state.lastPair=1;state.crouch=0;state.alive=true
 for key in ["sY","sP","sR","sL","sA","sA2"]:state[key]={"x":0.0,"v":0.0}
 for i in 4:
  state.feet[i].p=nominal_foot(i,position.x,position.z,yaw)
 scene.source_nodes[state.rig.group["$node"]].visible=true
 if update_pose:pose(.016,0)

func spring(key:String,target:float,stiffness:float,damping:float,dt:float)->float:
 var s:Dictionary=state[key];s.v+=((target-s.x)*stiffness-s.v*damping)*dt;s.x+=s.v*dt;return s.x

func step(dt:float)->void:
 var vx=sin(state.yaw)*state.speed+state.push.x;var vz=cos(state.yaw)*state.speed+state.push.z
 var moving=state.speed>.15 or absf(state.yawRate)>.25
 if state.sw<0:
  state.idleT=0 if moving else state.idleT+dt
  var motion=state.speed+absf(state.yawRate)*.5
  var duration=clampf(.27-motion*.026,.14,.27)
  var chosen=-1;var largest=0.0
  for pair in 2:
   var error=0.0
   for index in PAIRS[pair]:
    var target=nominal_foot(index,state.pos.x+vx*duration,state.pos.z+vz*duration,state.yaw+state.yawRate*duration)
    error=maxf(error,Vector2(target.x-state.feet[index].p.x,target.z-state.feet[index].p.z).length())
   if pair!=state.lastPair:error*=1.25
   if error>largest:largest=error;chosen=pair
  var threshold=.09 if moving else .035 if state.idleT>.25 else 1e9
  if chosen>=0 and largest>threshold:
   state.sw=chosen;state.swT=0;state.swDur=duration;state.lift=.065+minf(.09,motion*.02)
   for index in PAIRS[chosen]:
    var foot:Dictionary=state.feet[index];foot.from=foot.p
    foot.to=nominal_foot(index,state.pos.x+vx*duration*1.5,state.pos.z+vz*duration*1.5,state.yaw+state.yawRate*duration*1.5)
    foot.to.y=physics.ground_height(foot.to.x,foot.to.z,state.pos.y+.6)
 else:
  state.swT+=dt/state.swDur
  var phase=minf(state.swT,1);var eased=phase*phase*(3-2*phase)
  for index in PAIRS[int(state.sw)]:
   var foot:Dictionary=state.feet[index];foot.p=foot.from.lerp(foot.to,eased);foot.p.y+=sin(PI*phase)*state.lift
  if state.swT>=1:
   footstep.emit(state.feet[PAIRS[int(state.sw)][0]].p,float(state.speed))
   steps+=1;state.sY.v-=.12+state.speed*.03;state.lastPair=state.sw;state.sw=-1

func solve_leg(x:float,y:float,z:float,side:int)->Vector3:
 var radial=sqrt(maxf(x*x+y*y-.075*.075,.000001))
 var abduct=atan2(y,x)-atan2(-radial,side*.075)
 if abduct>PI:abduct-=TAU
 elif abduct< -PI:abduct+=TAU
 var lower=.42-.046*.6
 var reach=clampf(Vector2(radial,z).length(),absf(.4-lower)+.03,(.4+lower)*.995)
 var pitch=atan2(z,radial)
 var upper_angle=acos(clampf((.4*.4+reach*reach-lower*lower)/(2*.4*reach),-1,1))
 var knee_angle=acos(clampf((.4*.4+lower*lower-reach*reach)/(2*.4*lower),-1,1))
 return Vector3(abduct,upper_angle-pitch,-(PI-knee_angle))

func _bone(name:String,rotation:Basis,position:Variant=null)->void:
 var id:String=bones[name]["$node"];var local:Transform3D=scene.source_nodes[id].transform
 local.basis=rotation
 if position is Vector3:local.origin=position
 scene.set_source_transform(id,local)

func pose(dt:float,time:float)->void:
 var feet:Array=state.feet
 var front=(feet[0].p.y+feet[1].p.y)*.5;var rear=(feet[2].p.y+feet[3].p.y)*.5
 var left=(feet[0].p.y+feet[2].p.y)*.5;var right=(feet[1].p.y+feet[3].p.y)*.5
 var height=(front+rear)*.5-state.pos.y
 var acceleration=(state.speed-state.prevSpeed)/dt if dt>0 else 0.0
 var pitch=atan2(rear-front,.8)*.6+clampf(acceleration*.006,-.07,.07)
 var roll=atan2(left-right,.55)*.6+clampf(state.yawRate*state.speed*.02,-.12,.12)
 var vertical=height*.45-minf(.05,state.speed*.011)
 if state.alive:
  spring("sY",vertical,160,17,dt);spring("sP",pitch,130,15,dt);spring("sR",roll,130,15,dt);spring("sL",0,110,13,dt)
 var idle=sin(time*1.7+state.phase)*.004 if state.alive else 0.0
 var sway=float(state.sL.x);var body_y=.72+state.sY.x-state.crouch+idle
 var body_pitch=float(state.sP.x);var body_roll=float(state.sR.x)
 var group:Node3D=scene.source_nodes[state.rig.group["$node"]];group.position=state.pos;group.basis=Basis(Vector3.UP,state.yaw)
 _bone("body",Basis(Vector3.RIGHT,body_pitch)*Basis(Vector3.BACK,body_roll),Vector3(sway,body_y,0))
 _bone("turret",Basis(Vector3.UP,state.tyaw));_bone("gun",Basis(Vector3.RIGHT,state.tpitch-body_pitch*.5))
 _bone("head",Basis(Vector3.RIGHT,state.hpitch)*Basis(Vector3.UP,state.hyaw))
 spring("sA",clampf(-acceleration*.03-body_pitch,-.6,.6),60,5,dt);spring("sA2",clampf(state.yawRate*.12-body_roll,-.6,.6),60,5,dt)
 _bone("antenna",Basis(Vector3.RIGHT,state.sA.x)*Basis(Vector3.BACK,state.sA2.x))
 var cy=cos(state.yaw);var sy=sin(state.yaw);var cp=cos(body_pitch);var sp=sin(body_pitch);var cr=cos(body_roll);var sr=sin(body_roll)
 for i in 4:
  var delta:Vector3=feet[i].p-state.pos;delta.y+=.046*.6
  var local_x=delta.x*cy-delta.z*sy-sway
  var local_y=delta.y-body_y
  var local_z=delta.x*sy+delta.z*cy
  var rotated_y=local_y*cp+local_z*sp;var rotated_z=-local_y*sp+local_z*cp
  var leg_x=local_x*cr+rotated_y*sr;var leg_y=-local_x*sr+rotated_y*cr
  var angles=solve_leg(leg_x-SIDES[i]*.165,leg_y+.01,rotated_z-FORE[i]*.4,SIDES[i])
  _bone("abd"+LEGS[i],Basis(Vector3.BACK,angles.x));_bone("thigh"+LEGS[i],Basis(Vector3.RIGHT,angles.y));_bone("shin"+LEGS[i],Basis(Vector3.RIGHT,angles.z))
 state.headPos=scene.source_nodes[bones.head["$node"]].global_position
