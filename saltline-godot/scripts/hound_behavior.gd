class_name SaltlineHoundBehavior
extends RefCounted

signal telegraph(duration:float,melee:bool)
signal shot_requested
signal melee_requested(damage:float,position:Vector3)

var state:Dictionary
var locomotion:SaltlineHoundLocomotion
var coordinator:SaltlineEnemyCoordinator
var tuning:Dictionary
var rng:SaltlineSourceRng
var cover_points:Array=[]
var crouch_target=0.0
var lunging=false
var turret_target:Variant=null
var head_target:Variant=null

func _init(actor_state:Dictionary,movement:SaltlineHoundLocomotion,manager:SaltlineEnemyCoordinator,covers:Array=[])->void:
 state=actor_state;locomotion=movement;coordinator=manager;tuning=movement.tuning;rng=manager.rng;cover_points=covers
 for key in ["home","lastKnown","firePos","firePlayer","sensor","fwd"]:
  if state.get(key) is Array:
   var value:Array=state[key];state[key]=Vector3(value[0],value[1],value[2])
 if state.get("patrolLine") is Array:
  for i in state.patrolLine.size():
   if state.patrolLine[i] is Array:
    var value:Array=state.patrolLine[i];state.patrolLine[i]=Vector3(value[0],value[1],value[2])
 locomotion.reposition_requested.connect(select_fire_position)

func _score_position(candidate:Vector3,bias:float,best:Dictionary)->void:
 var player=coordinator.player
 var distance=Vector2(candidate.x-player.pos.x,candidate.z-player.pos.z).length()
 if distance<tuning.rangeMin or distance>tuning.rangeMax or not locomotion.navigation.is_walkable(candidate.x,candidate.z):return
 var score=Vector2(candidate.x-state.pos.x,candidate.z-state.pos.z).length()*.9+bias+rng.randf()*3
 var offset=Vector2(candidate.x-player.pos.x,candidate.z-player.pos.z)
 for other in coordinator.list:
  if other.id==state.id or not other.alive or other.type!="hound" or other.mode!="engage":continue
  var position:Vector3=other.firePos if other.es=="move" else other.pos
  var direction=Vector2(position.x-player.pos.x,position.z-player.pos.z)
  var alignment=offset.dot(direction)/(offset.length()*direction.length()+.0001)
  if alignment>.86:score+=14*(alignment-.86)/.14
  if Vector2(candidate.x-position.x,candidate.z-position.z).length()<3:score+=16
 if score>=best.score:return
 if not locomotion.physics.line_of_sight(candidate+Vector3(0,.95,0),player.eye):score+=22
 if score<best.score:best.score=score;state.firePos=candidate

func select_fire_position()->void:
 var player=coordinator.player
 if player==null:return
 var best={"score":INF}
 for point in cover_points:_score_position(point,-2,best)
 for i in 7:_score_position(locomotion.navigation.random_point(player.pos,tuning.rangeMax),0,best)
 var angle=atan2(state.pos.z-player.pos.z,state.pos.x-player.pos.x)
 for i in 5:
  var direction=angle+(rng.randf()-.5)*2.6
  var distance=tuning.rangeMin+1+rng.randf()*(tuning.rangeMax-tuning.rangeMin-2)
  var point=Vector3(player.pos.x+cos(direction)*distance,player.pos.y,player.pos.z+sin(direction)*distance)
  point.y=locomotion.physics.ground_height(point.x,point.z,player.pos.y+1)
  _score_position(point,1,best)
 if best.score==INF:state.firePos=state.pos
 state.firePlayer=player.pos;locomotion.set_goal(state.firePos,true)
 state.es="move";state.esT=0;state.moveT=0;state.bursts=0

# Original S decision phase. Movement, world-foot stepping and pose follow this phase.
func decide(dt:float)->void:
 var player=coordinator.player
 state.fwd=Vector3(sin(state.yaw),0,cos(state.yaw));state.sensor=state.headPos
 coordinator.think(state,dt,.55)
 if state.mode!=state.modeSeen:
  state.modeSeen=state.mode;state.hasGoal=false;state.path=null;state.waitT=0
  if state.mode=="engage":select_fire_position()
  elif state.es=="tele" or state.es=="burst":coordinator.release_token(state);state.es="move"
 state.wantYaw=state.yaw;state.maxSpeed=0;state.cool-=dt;state.lungeCd-=dt
 turret_target=null;head_target=null;crouch_target=0;lunging=false
 var distance=Vector2(player.pos.x-state.pos.x,player.pos.z-state.pos.z).length() if player!=null else 1e9
 if state.mode=="patrol":
  if state.hasGoal:
   if locomotion.follow_goal(dt,tuning.patrolSpeed):state.waitT=1.5+rng.randf()*3
  else:
   state.waitT-=dt
   if state.waitT<=0:
    if state.get("patrolLine")!=null:
     state.patrolI=(int(state.patrolI)+1)%state.patrolLine.size();locomotion.set_goal(state.patrolLine[state.patrolI],true)
    else:locomotion.set_goal(locomotion.navigation.random_point(state.home,state.patrolR),true)
 elif state.mode=="investigate" or state.mode=="search":
  head_target=state.lastKnown
  var remaining=Vector2(state.lastKnown.x-state.pos.x,state.lastKnown.z-state.pos.z).length()
  if remaining>2.2:
   locomotion.set_goal(state.lastKnown);locomotion.follow_goal(dt,tuning.stalkSpeed if remaining<8 else tuning.runSpeed)
  else:state.hasGoal=false;state.scan+=dt;state.wantYaw=state.yaw+sin(state.scan*.8)*.9;head_target=null
 elif player!=null:
  turret_target=player.pos;head_target=player.pos
  var yaw=atan2(player.pos.x-state.pos.x,player.pos.z-state.pos.z)
  if state.es in ["move","aim","cool"] and distance<tuning.lungeRange and state.lungeCd<=0 and player.alive:
   state.es="wind";state.esT=.28;coordinator.release_token(state);telegraph.emit(.28,true)
  match state.es:
   "move":
    state.moveT+=dt
    var arrived=locomotion.follow_goal(dt,tuning.runSpeed)
    var in_range=distance>tuning.rangeMin-1 and distance<tuning.rangeMax+2
    if arrived or (state.moveT>1.4 and state.los and in_range and rng.randf()<dt*.7) or state.moveT>7:
     state.es="aim";state.esT=0;state.hasGoal=false
    elif player.pos.distance_squared_to(state.firePlayer)>49:select_fire_position()
   "aim","cool":
    state.wantYaw=yaw;state.esT+=dt
    if state.los:
     if distance<tuning.rangeMin-3 and state.esT>.8:select_fire_position()
     elif state.cool<=0 and player.alive and absf(locomotion.angle_delta(yaw-state.yaw,state.tyaw))<.14 and coordinator.request_token(state):
      state.es="tele";state.esT=tuning.telegraph;telegraph.emit(tuning.telegraph,false)
    elif state.noSeeT>1.1 or state.esT>3:select_fire_position()
   "tele":
    state.wantYaw=yaw;state.esT-=dt;state.flare=minf(1,state.flare+dt*5);crouch_target=.05
    if state.esT<=0:state.es="burst";state.shots=tuning.burst;state.esT=0
   "burst":
    state.wantYaw=yaw;state.esT-=dt;state.flare=1;crouch_target=.05
    if state.esT<=0:state.esT=tuning.burstGap;state.shots-=1;shot_requested.emit()
    if state.shots<=0:
     coordinator.release_token(state);state.cool=tuning.cooldown[0]+rng.randf()*(tuning.cooldown[1]-tuning.cooldown[0]);state.bursts+=1
     if state.bursts>=1+(1 if rng.randf()<.4 else 0):select_fire_position()
     else:state.es="cool";state.esT=0
   "wind":
    state.wantYaw=yaw;state.esT-=dt;crouch_target=.16;state.sP.v+=3*dt
    if state.esT<=0:state.es="lunge";state.esT=.36;state.speed=tuning.lungeSpeed;state.yaw=yaw
   "lunge":
    lunging=true;state.esT-=dt;state.wantYaw=yaw;state.maxSpeed=tuning.lungeSpeed;state.speed=tuning.lungeSpeed
    if distance<1.35 and player.alive:melee_requested.emit(tuning.lungeDamage,state.pos);state.esT=0;state.sP.v-=4
    if state.esT<=0:state.es="recover";state.esT=.55;state.lungeCd=tuning.lungeCooldown;state.speed*=.3
   "recover":
    state.esT-=dt;state.wantYaw=yaw
    if state.esT<=0:select_fire_position()

# Call after movement and foot stepping, before HoundPose.pose().
func aim(dt:float)->void:
 state.crouch+=(crouch_target-state.crouch)*(1-exp(-12*dt))
 var cy=cos(state.yaw);var sy=sin(state.yaw)
 var turret_yaw=0.0;var turret_pitch=0.0;var head_yaw=0.0;var head_pitch=.05
 var body_y=state.pos.y+.72+state.sY.x-state.crouch
 if turret_target!=null:
  var dx=turret_target.x-state.pos.x;var dz=turret_target.z-state.pos.z
  var dy=turret_target.y+1-(body_y+.25)
  turret_yaw=atan2(dx*cy-dz*sy,dx*sy+dz*cy)
  turret_pitch=clampf(atan2(-dy,Vector2(dx,dz).length()),-.9,.35)
 else:state.scan+=dt*.5;turret_yaw=sin(state.scan*.9+state.phase)*1.1
 if head_target!=null:
  var dx=head_target.x-state.pos.x;var dz=head_target.z-state.pos.z
  var dy=head_target.y+1.2-(body_y+.2)
  head_yaw=clampf(atan2(dx*cy-dz*sy,dx*sy+dz*cy),-1.2,1.2)
  head_pitch=clampf(atan2(-dy,Vector2(dx,dz).length()),-.6,.5)
 else:head_yaw=sin(coordinator.time*.7+state.phase)*.5+clampf(state.yawRate*.25,-.6,.6)
 var maximum=clampf(4.5*dt,0,1)
 state.tyaw+=clampf(locomotion.angle_delta(turret_yaw,state.tyaw),-maximum,maximum)
 state.tpitch+=(turret_pitch-state.tpitch)*(1-exp(-10*dt))
 var blend=1-exp(-7*dt);state.hyaw+=(head_yaw-state.hyaw)*blend;state.hpitch+=(head_pitch-state.hpitch)*blend
