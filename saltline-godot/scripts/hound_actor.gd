class_name SaltlineHoundActor
extends RefCounted

signal shot(origin:Vector3,direction:Vector3,damage:float)
signal melee(damage:float,position:Vector3)
signal killed(actor:SaltlineHoundActor)
signal retirement_requested(actor:SaltlineHoundActor)
var pose:SaltlineHoundPose
var movement:SaltlineHoundLocomotion
var behavior:SaltlineHoundBehavior
var life:SaltlineHoundLife
var state:Dictionary
var coordinator:SaltlineEnemyCoordinator
var effects:SaltlineImpactEffects
var scene:SaltlineSourceScene
var shots_fired=0
var impacts_received=0
var visited_states={}

func _init(source:SaltlineSourceScene,record:Dictionary,nav:SaltlineNavigation,manager:SaltlineEnemyCoordinator,fx:SaltlineImpactEffects,covers:Array=[])->void:
 scene=source;coordinator=manager;effects=fx
 pose=SaltlineHoundPose.new(source,record,nav.physics);state=pose.state
 movement=SaltlineHoundLocomotion.new(state,nav,manager.tuning.hound,manager.rng)
 behavior=SaltlineHoundBehavior.new(state,movement,manager,covers)
 life=SaltlineHoundLife.new(state,manager)
 behavior.shot_requested.connect(_shoot)
 behavior.melee_requested.connect(func(amount,position):melee.emit(amount,position))
 life.pose_requested.connect(func(dt):pose.pose(dt,coordinator.time))
 life.lens_requested.connect(_lens)
 life.effect_requested.connect(_effect)
 life.killed.connect(_killed)
 life.retired.connect(_request_retire)
 life.hit_received.connect(func(_point,_part):impacts_received+=1)

func activate(position:Vector3,options:Dictionary={})->void:
 var rng=coordinator.rng
 state.active=true;state.alive=true;state.wreck=false;state.hp=coordinator.tuning.hound.hp;state.passive=options.get("passive",false);state.sink=0
 var ground=movement.physics.ground_height(position.x,position.z,position.y+1);position.y=ground
 var yaw=float(options.yaw) if options.has("yaw") else rng.randf()*6.283
 state.home=position;state.mode="investigate" if options.get("state","")=="alert" else "patrol";state.modeT=10;state.modeSeen=state.mode
 state.lastKnown=options.get("target",coordinator.player.pos if coordinator.player!=null else position)
 state.los=false;state.seeT=0;state.noSeeT=0;state.exposure=0;state.senseT=rng.randf()*.2;state.hasToken=false
 state.patrolR=options.get("patrolRadius",7);state.patrolLine=options.get("patrolLine");state.patrolI=0;state.es="move";state.cool=.6+rng.randf();state.lungeCd=.3
 state.path=null;state.hasGoal=false;state.waitT=rng.randf()*1.5;state.planT=0;state.feelT=0;state.blocked=false;state.flare=0;state.phase=rng.randf()*6.283;state.dieT=0
 state.tyaw=0;state.hyaw=0;state.tpitch=0;state.hpitch=0
 var last_pair=state.lastPair;var previous_speed=state.prevSpeed;pose.reset(position,yaw,false);state.lastPair=last_pair;state.prevSpeed=previous_speed
 pose._bone("neck",Basis.IDENTITY);pose._bone("gun",Basis.IDENTITY);pose.pose(.016,coordinator.time)

func deactivate()->void:
 state.active=false;state.alive=false;state.wreck=false;coordinator.release_token(state)
 scene.source_nodes[state.rig.group["$node"]].visible=false

func update(dt:float)->void:
 if not state.active:return
 dt=minf(dt,.05)
 if state.alive:
  behavior.decide(dt);movement.move(dt,coordinator.list,coordinator.player,behavior.lunging)
  pose.step(dt);behavior.aim(dt);pose.pose(dt,coordinator.time)
  var phase=fmod(coordinator.time*(.8 if state.mode=="patrol" else 2.2)+state.phase,1)
  var beacon:Node3D=scene.source_nodes[pose.bones.beacon["$node"]]
  beacon.scale=Vector3.ONE*(1 if phase<.12 or (phase>.22 and phase<.3) else .0001)
  var color=Vector3(14,1,.35) if state.mode=="engage" else Vector3(8,4,.7)
  for i in 3:state.lensC[i]+=(color[i]-state.lensC[i])*(1-exp(-8*dt))
  _lens(Vector3(state.lensC[0],state.lensC[1],state.lensC[2])*(1+state.flare*3.5));state.flare=maxf(0,state.flare-dt*2)
  if state.hp<coordinator.tuning.hound.hp*coordinator.tuning.hound.smokeBelow:
   state.smokeT-=dt
   if state.smokeT<=0:
    state.smokeT=.2
    var position=state.pos-Vector3(sin(state.yaw),0,cos(state.yaw))*.3
    position.y=state.pos.y+.72+state.sY.x-state.crouch+.2
    _effect("smoke",position,{"size":.35,"life":1.3,"color":2303272,"rise":.9})
    if coordinator.rng.randf()<.2:_effect("sparks",position,{"normal":Vector3.UP,"count":3})
  visited_states[state.es]=true
 else:
  life.update(dt)
  scene.source_nodes[state.rig.group["$node"]].position=state.pos

func _lens(color:Vector3)->void:
 var material:ShaderMaterial=scene.materials[state.lens["$material"]]
 material.set_shader_parameter("base_color",color)

func _killed()->void:
 scene.source_nodes[pose.bones.beacon["$node"]].scale=Vector3.ONE*.0001
 killed.emit(self)

func _shoot()->void:
 var player=coordinator.player
 if player==null:return
 var origin:Vector3=scene.source_nodes[pose.bones.gun["$node"]].global_position
 if origin.length_squared()<1e-6 or absf(origin.x-state.pos.x)>2:origin=state.pos+Vector3(0,.97,0)
 var target:Vector3=player.pos+Vector3.UP
 var direction=(target-origin).normalized();state.muzzle=origin+direction*.43
 var settings:Dictionary=coordinator.tuning.hound
 var player_speed=float(coordinator.get_meta("player_speed",0))
 var spread=(settings.spreadFar+(settings.spreadNear-settings.spreadFar)*state.exposure)*(1+player_speed*.3)
 direction.x+=(coordinator.rng.randf()-.5)*2*spread;direction.y+=(coordinator.rng.randf()-.5)*2*spread;direction.z+=(coordinator.rng.randf()-.5)*2*spread
 direction=direction.normalized();shot.emit(state.muzzle,direction,settings.shotDamage);shots_fired+=1
 state.sP.v+=1.1;state.sY.v-=.25

func _effect(kind:String,position:Vector3,options:Dictionary)->void:
 if effects==null:return
 match kind:
  "smoke":effects.smoke(position,options)
  "sparks":effects.sparks(position,options.get("normal",Vector3.UP),options.get("count",12))
  "debris":effects.fragments(position,Vector3.UP,options.get("count",6),2,6.5,Vector3(.024,.018,.024),Vector3(.072,.054,.072),Vector3(.4,.39,.37),1)
  "crash":effects.dust(position,Vector3.UP,1,Vector3(.5,.48,.45))

func dispose()->void:
 for emitter in [life,behavior,movement]:
  for info in emitter.get_signal_list():
   for connection in emitter.get_signal_connection_list(info.name):emitter.disconnect(info.name,connection.callable)

func raycast(origin:Vector3,direction:Vector3,limit:float,hit:Dictionary)->bool:
 var found=SaltlineEnemyHitShapes.hound(state,origin,direction,limit,hit)
 if found:hit.actor=self
 return found

func damage(amount:float,point:Vector3,direction:Variant=null,part:String="body")->bool:
 return life.damage(amount,point,direction,part)

func _request_retire()->void:
 if retirement_requested.get_connections().is_empty():deactivate()
 else:retirement_requested.emit(self)
