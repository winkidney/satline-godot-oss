class_name SaltlineGullActor
extends RefCounted

signal killed(actor:SaltlineGullActor)
signal retirement_requested(actor:SaltlineGullActor)
signal bolt_requested(position:Vector3,direction:Vector3)
signal explosion_requested(position:Vector3,radius:float,damage:float)
signal blast_effect(position:Vector3,size:float)
var state:Dictionary
var flight:SaltlineGullFlight
var behavior:SaltlineGullBehavior
var pose:SaltlineGullPose
var life:SaltlineGullLife
var scene:SaltlineSourceScene
var coordinator:SaltlineEnemyCoordinator
var effects:SaltlineImpactEffects
var bolts_fired=0
var visited_states={}

func _init(source:SaltlineSourceScene,record:Dictionary,manager:SaltlineEnemyCoordinator,fx:SaltlineImpactEffects)->void:
 scene=source;state=record.duplicate(true);coordinator=manager;effects=fx
 flight=SaltlineGullFlight.new(state,manager);behavior=SaltlineGullBehavior.new(flight);pose=SaltlineGullPose.new(source,record,flight,behavior);life=SaltlineGullLife.new(flight)
 behavior.bolt_requested.connect(_bolt);behavior.effect_requested.connect(_effect)
 life.effect_requested.connect(_effect);life.explosion_requested.connect(func(position,radius,amount):explosion_requested.emit(position,radius,amount))
 life.killed.connect(_killed);life.retired.connect(func():retirement_requested.emit(self))
 life.rotor_lost.connect(func(index):pose.scale_bone("rotor%d"%index,.0001))
 life.pose_requested.connect(_death_pose)

func activate(position:Vector3,options:Dictionary={})->void:
 var rng=coordinator.rng;var tuning=flight.tuning
 state.active=true;state.alive=true;state.hp=tuning.hp;state.passive=options.get("passive",false);state.pos=position;state.home=position;state.vel=Vector3.ZERO
 state.yaw=float(options.yaw) if options.has("yaw") else rng.randf()*6.283;state.pitch=0;state.roll=0
 state.mode="investigate" if options.get("state")=="alert" else "patrol";state.modeT=8
 state.lastKnown=options.get("target",coordinator.player.pos if coordinator.player!=null else position)
 state.los=false;state.seeT=0;state.noSeeT=0;state.exposure=0;state.senseT=rng.randf()*.2;state.hasToken=false
 state.orbitDir=1 if rng.randf()<.5 else -1;state.orbitR=tuning.rangeMin+2+rng.randf()*(tuning.rangeMax-tuning.rangeMin-5)
 state.alt=float(options.hover) if options.get("hover")!=null else tuning.altMin+.8+rng.randf()*(tuning.altMax-tuning.altMin-1.6)
 state.hoverFixed=options.get("hover")!=null;state.patrolR=float(options.patrolRadius) if options.has("patrolRadius") else 4+rng.randf()*5
 state.phase=rng.randf()*6.283;state.orbitA=rng.randf()*6.283;state.ceil=1e9;state.flipT=3+rng.randf()*4;state.atk="idle";state.cool=1+rng.randf()*1.5
 state.dieT=0;state.spin=0;state.lostRotor=-1;state.flare=0;state.thr=1;pose.activate()

func deactivate()->void:
 state.active=false;state.alive=false;coordinator.release_token(state);scene.source_nodes[state.rig.group["$node"]].visible=false

func update(dt:float)->void:
 if not state.active:return
 if state.alive:
  flight.update(dt);behavior.update(dt);pose.update();visited_states[state.atk]=true
 else:life.update(dt)

func _bolt(position:Vector3,direction:Vector3)->void:bolts_fired+=1;bolt_requested.emit(position,direction)

func _killed()->void:
 for name in ["lamp","strobeG","strobeR","strobeW"]:pose.scale_bone(name,.0001)
 pose.lens(Vector3(.3,.05,.02));killed.emit(self)

func _death_pose()->void:
 pose.group_pose()
 for i in 4:
  if i!=state.lostRotor:pose.bone("rotor%d"%i,Basis(Vector3.UP,flight.rotor_angles[i]))

func damage(amount:float,point:Vector3,direction:Variant=null,part:String="body")->bool:return life.damage(amount,point,direction,part)

func raycast(origin:Vector3,direction:Vector3,limit:float,hit:Dictionary)->bool:
 var found=SaltlineEnemyHitShapes.gull(state,origin,direction,limit,hit)
 if found:hit.actor=self
 return found

func _effect(kind:String,position:Vector3,options:Dictionary)->void:
 if effects==null:return
 match kind:
  "smoke":effects.smoke(position,options)
  "sparks":effects.sparks(position,options.get("normal",Vector3.UP),options.get("count",12))
  "debris":effects.fragments(position,Vector3.UP,options.get("count",3),2,6.5,Vector3(.024,.018,.024),Vector3(.072,.054,.072),Vector3(.4,.39,.37),1)
  "explosion":blast_effect.emit(position,options.size)

func dispose()->void:
 for emitter in [life,behavior]:
  for info in emitter.get_signal_list():
   for connection in emitter.get_signal_connection_list(info.name):emitter.disconnect(info.name,connection.callable)
