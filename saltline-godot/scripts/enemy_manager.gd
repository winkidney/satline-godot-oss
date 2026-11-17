class_name SaltlineEnemyManager
extends RefCounted

signal spawned(actor:Variant)
signal noise_alerted(actor:Variant)
var coordinator:SaltlineEnemyCoordinator
var combat:SaltlineCombat
var pools={"gull":[],"hound":[]}
var active:Array=[]
var wrecks:Array=[]
var next_id=1
var noise_cooldown=0.0
var player_speed=0.0
var bolts:SaltlineBolts
var scan_light:SaltlineGullScanLight
var camera:Camera3D

func _init(manager:SaltlineEnemyCoordinator,battle:SaltlineCombat)->void:
 coordinator=manager;combat=battle;combat.enemies=active

func add_to_pool(kind:String,actor:Variant)->void:
 pools[kind].append(actor);actor.deactivate();combat.register_actor(actor,false)
 if kind=="hound":actor.killed.connect(add_wreck)
 actor.retirement_requested.connect(retire)

func spawn(kind:String,position:Vector3,options:Dictionary={})->Variant:
 if not pools.has(kind):return null
 var actor:Variant=null
 for candidate in pools[kind]:
  if not candidate.state.active:actor=candidate;break
 if actor==null and kind=="hound" and not wrecks.is_empty():
  actor=wrecks[0];retire(actor)
 if actor==null:return null
 actor.state.id=next_id;next_id+=1;active.append(actor);coordinator.list.append(actor.state)
 actor.activate(position,options);spawned.emit(actor);return actor

func add_wreck(actor:Variant)->void:
 wrecks.append(actor)
 while wrecks.size()>int(coordinator.tuning.maxWrecks):
  var oldest=wrecks.pop_front()
  if oldest.state.active:oldest.state.sink=.001

func retire(actor:Variant)->void:
 actor.deactivate();active.erase(actor);coordinator.list.erase(actor.state);wrecks.erase(actor)

func alive_count()->int:
 var count=0
 for actor in active:
  if actor.state.alive:count+=1
 return count

func clear()->void:
 for kind in ["gull","hound"]:
  for actor in pools[kind]:
   if actor.state.active:actor.deactivate()
 active.clear();coordinator.list.clear();wrecks.clear();coordinator.tokens=0
 if bolts!=null:bolts.clear()
 if scan_light!=null:scan_light.clear()
 # Source clear preserves time, next ID, RNG, token time/type and fairness history.

func alert(position:Vector3,radius:float=40)->void:
 for actor in active:
  var state:Dictionary=actor.state
  if not state.alive or state.passive or state.mode=="engage" or state.pos.distance_squared_to(position)>radius*radius:continue
  state.lastKnown=position;state.lastKnown.y=maxf(0,position.y-1.6)
  if state.mode=="patrol":noise_alerted.emit(actor)
  state.mode="investigate";state.modeT=9+coordinator.rng.randf()*4

func weapon_fire(position:Vector3)->void:
 if noise_cooldown>0:return
 noise_cooldown=.3;alert(position,float(coordinator.tuning.hearRadius))

func explosion(position:Vector3)->void:alert(position,30)

func update(dt:float)->void:
 if dt<=0:return
 dt=minf(dt,.05);coordinator.time+=dt;noise_cooldown-=dt
 var player=coordinator.player
 if player!=null:
  var speed=Vector2(player.velocity.x,player.velocity.z).length() if "velocity" in player else player.speed
  player_speed+=(speed-player_speed)*(1-exp(-6*dt))
 coordinator.set_meta("player_speed",player_speed)
 for i in range(active.size()-1,-1,-1):active[i].update(dt)
 if bolts!=null:bolts.update(dt)
 if scan_light!=null:scan_light.update(dt,active,camera.global_position if camera!=null else null)

func dispose()->void:
 clear()
 if scan_light!=null:scan_light.dispose()
 for kind in pools:
  for actor in pools[kind]:
   if kind=="hound" and actor.killed.is_connected(add_wreck):actor.killed.disconnect(add_wreck)
   if actor.retirement_requested.is_connected(retire):actor.retirement_requested.disconnect(retire)
   actor.dispose()
 combat.dispose()
 for kind in pools:pools[kind].clear()
