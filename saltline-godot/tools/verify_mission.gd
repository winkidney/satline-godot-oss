extends SceneTree
class PhysicsStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func line_of_sight(origin:Vector3,_target:Vector3)->bool:return origin.x<0
class NavStub extends SaltlineNavigation:
 func is_walkable(x:float,z:float)->bool:return absf(x)<35 and absf(z)<29
class PlayerStub extends RefCounted:
 signal died
 signal hit(amount:float,from_position:Variant)
 var tuning:Dictionary
 var pos=Vector3.ZERO
 var eye=Vector3.ZERO
 var forward=Vector3.FORWARD
 var health=100.0
 var alive=true
 var shake=0.0
 var invulnerable=false
 var enabled=true
 func reset(position:Vector3)->void:pos=position;eye=pos+Vector3(0,1.68,0);health=100;alive=true;invulnerable=false;enabled=true
 func heal(amount:float)->void:
  if alive:health=minf(100,health+amount)
 func damage(amount:float)->void:
  if not alive or invulnerable:return
  health=maxf(0,health-amount);hit.emit(amount,null)
  if health==0:alive=false;died.emit()
class ActorStub extends RefCounted:
 signal killed(actor:Variant)
 var state:Dictionary
 func _init(id:int,kind:String,position:Vector3)->void:state={"id":id,"type":kind,"pos":position,"alive":true}
class ManagerStub extends SaltlineEnemyManager:
 var spawn_calls=0
 var failed=0
 var alerts=0
 var fail_spawn=false
 func spawn(kind:String,position:Vector3,_options:Dictionary={})->Variant:
  spawn_calls+=1
  if fail_spawn:failed+=1;return null
  var actor=ActorStub.new(next_id,kind,position);next_id+=1;active.append(actor);return actor
 func clear()->void:active.clear()
 func alert(_position:Vector3,_radius:float=40)->void:alerts+=1
var radio_events=[]
var progress_count=0
var done_count=0
var all_count=0
var relay_states=[]
var reserve=150
var explosive_resets=0
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Dictionary:
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is float or a is int:
  if b==null:return false
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.001
 return a==b
func snapshot(mission:SaltlineMission)->Dictionary:
 var manager:ManagerStub=mission.manager;var run={}
 for key in ["time","retries","cut","allCut","queue","waveHot","alertT","pursuitT","pursuitLeft","extractHint","intensity","mode","wave","waveOn","breakT","score","kills","wavesCleared","contactSaid","lowSaid"]:run[key]=mission.run[key]
 var used={}
 for index in mission.run.used:used[str(index)]=mission.run.used[index]
 run.used=used
 var relays=[];var active=[]
 for relay in mission.relays:relays.append({"id":relay.id,"t":relay.t,"cut":relay.cut,"cutting":relay.cutting})
 for actor in manager.active:active.append(actor.state)
 return {"state":mission.state,"radioEvents":radio_events,"run":run,"relays":relays,"active":active,"flow":mission.flow,"tuning":manager.coordinator.tuning,"regen":[mission.player.tuning.regenDelay,mission.player.tuning.regenRate],"playerHealth":mission.player.health,"progress":progress_count,"done":done_count,"all":all_count,"relayStates":relay_states,"spawnCalls":manager.spawn_calls,"failed":manager.failed,"alerts":manager.alerts,"nextId":manager.next_id,"reserve":reserve,"explosiveResets":explosive_resets,"debrief":null if mission.debrief.is_empty() else mission.debrief}
func compare_snapshot(actual:Dictionary,expected:Dictionary,label:String,failures:Array)->void:
 for key in expected:
  if not same(actual[key],expected[key]):failures.append(label+" "+key)
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var rules=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-rules.json"))
 var canonical=OS.get_cmdline_user_args().has("--canonical")
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/mission-canonical-reference.json" if canonical else "res://assets/export/fixtures/mission-reference.json"))
 var physics=PhysicsStub.new();var player=PlayerStub.new();player.tuning=rules.player.duplicate(true)
 var coordinator=SaltlineEnemyCoordinator.new(rules.enemies.duplicate(true),physics,player);var combat=SaltlineCombat.new(physics,player);var manager=ManagerStub.new(coordinator,combat)
 var mission=SaltlineMission.new(data.modules.level,manager,player,NavStub.new(physics),null if canonical else SaltlineSourceRng.new(1337));var failures=[]
 mission.radio_requested.connect(func(text,seconds):radio_events.append([text,seconds]));mission.radio_cleared.connect(func():radio_events.append(["clear"]))
 mission.progress.connect(func(_id,_value):progress_count+=1);mission.objective_done.connect(func(_id,_index,_total):done_count+=1);mission.objective_all.connect(func():all_count+=1)
 mission.relay_changed.connect(func(relay,visual):relay_states.append([relay.id,visual]))
 mission.resupply.connect(func(amount,cap,reset):reserve=mini(cap,reserve+amount);explosive_resets+=int(reset))
 for sample in reference.difficulties:
  mission.set_difficulty(sample.key)
  if not same(mission.flow,sample.flow) or not same(coordinator.tuning,sample.tuning) or not same([player.tuning.regenDelay,player.tuning.regenRate],sample.regen):failures.append("difficulty "+sample.key)
 mission.set_difficulty("hard");var start=data.modules.level.playerStart.pos;player.reset(Vector3(start[0],start[1],start[2]));explosive_resets+=1;mission.begin("mission")
 compare_snapshot(snapshot(mission),reference.initial,"initial",failures)
 for frame in reference.frames.size():
  var index=0 if frame<110 else 1 if frame<170 else 2;var point=data.modules.level.objectives[index].pos
  player.pos=Vector3(point[0],point[1],point[2]+1.5);player.forward=Vector3(0,0,1 if frame<10 else -1)
  if frame>=230:var position=data.modules.level.extraction.pos;player.pos=Vector3(position[0],position[1],position[2])
  player.eye=player.pos+Vector3(0,1.68,0);manager.fail_spawn=frame>=120 and frame<210
  if frame==160:
   for actor in manager.active:actor.state.alive=false
  if frame==220:combat.stats={"shots":10,"hits":6,"kills":4}
  if frame==15 or frame==16:mission._on_alert({})
  if frame==45:player.damage(75)
  mission.update(1.0/20,frame<40 or frame>=50)
  compare_snapshot(snapshot(mission),reference.frames[frame],"mission %d"%frame,failures)
 manager.fail_spawn=false;player.reset(Vector3(start[0],start[1],start[2]));reserve=150;explosive_resets+=1;mission.begin("holdout")
 compare_snapshot(snapshot(mission),reference.holdoutInitial,"holdout initial",failures)
 for frame in reference.holdout.size():
  if frame==140:player.damage(40)
  if frame%20==19:
   for actor in manager.active:
    if actor.state.alive:actor.state.alive=false;mission._on_killed(actor)
  mission.update(1.0/20,false)
  compare_snapshot(snapshot(mission),reference.holdout[frame],"holdout %d"%frame,failures)
 var report={"canonical":canonical,"failures":failures,"mission_frames":reference.frames.size(),"holdout_frames":reference.holdout.size(),"comparisons":comparisons,"maximum_error":maximum,"waves":mission.run.wave,"score":mission.run.score,"failed_spawn_attempts":manager.failed,"scope":reference.scope}
 mission.dispose();manager.dispose()
 var file=FileAccess.open("res://evidence/mission-canonical-verification.json" if canonical else "res://evidence/mission-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,12),"comparisons":comparisons,"maximum_error":maximum,"waves":report.waves,"score":report.score,"failed_spawn_attempts":report.failed_spawn_attempts}));quit(0 if failures.is_empty() else 1)
