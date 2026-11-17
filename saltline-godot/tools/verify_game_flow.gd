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
var resets=0
var intro_radio=0
var location=false
var maximum=0.0
var comparisons=0
var mission:SaltlineMission
var player:PlayerStub
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Array:
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0001
 return a==b
func reset_run(mode:String,keep:bool)->void:
 resets+=1;mission.manager.clear();mission.manager.combat.reset_stats();mission.reset_run(mode,keep)
 var start=mission.level.playerStart.pos;player.reset(Vector3(start[0],start[1],start[2]))
 if mode!="holdout":mission.spawn_patrol()
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var rules=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-rules.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/game-flow-reference.json"))
 var physics=PhysicsStub.new();player=PlayerStub.new();player.tuning=rules.player.duplicate(true)
 var coordinator=SaltlineEnemyCoordinator.new(rules.enemies.duplicate(true),physics,player);var combat=SaltlineCombat.new(physics,player);var manager=ManagerStub.new(coordinator,combat)
 mission=SaltlineMission.new(data.modules.level,manager,player,NavStub.new(physics),SaltlineSourceRng.new(1337))
 var camera=Camera3D.new();root.add_child(camera);var flow=SaltlineGameFlow.new(mission,camera,"")
 flow.reset_requested.connect(reset_run);flow.intro_card_changed.connect(func(value):location=value);flow.radio_requested.connect(func(_text,_duration):intro_radio+=1)
 var failures=[]
 for frame in reference.frames.size():
  var pause_pressed=frame in [140,144,149,165]
  if frame==120:flow.start()
  if frame==175:flow.resume()
  if frame==190:player.damage(200)
  if frame==230:flow.retry()
  if frame==260:
   for relay in mission.relays:mission.cut_relay(relay)
   player.pos=mission.extraction.pos
  if frame==340:flow.selected_mode="holdout";flow.redeploy()
  if frame==370:flow.start("holdout",false,false,true)
  if frame==380:mission.run.merge({"score":1234.6,"wave":3,"wavesCleared":2,"kills":12},true);player.damage(200)
  if frame==420:flow.retry()
  if frame==450:mission.run.merge({"score":900,"wave":1,"wavesCleared":0,"kills":9},true);player.damage(200)
  var gate=flow.update(1.0/20,false,pause_pressed)
  var row={"state":flow.state,"menu":flow.menu,"elapsed":flow.elapsed,"pauseDelay":flow.pause_delay,"titleTime":flow.title_time,"titleLength":flow.title_length,"fade":flow.fade,"saturation":flow.saturation,"location":location,"introRadio":intro_radio,"time":mission.run.time,"retries":mission.run.retries,"mode":mission.run.mode,"health":player.health,"alive":player.alive,"enabled":player.enabled,"invulnerable":player.invulnerable,"explosiveResets":resets,"camera":camera.global_position,"target":flow.title_target,"roll":camera.rotation.z,"fov":camera.fov,"best":flow.best_score,"gate":gate}
  for key in reference.frames[frame]:
   if not same(row[key],reference.frames[frame][key]):failures.append("%d %s"%[frame,key])
 var report={"failures":failures,"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"best_score":flow.best_score,"resets":resets,"scope":reference.scope}
 flow.dispose();mission.dispose();manager.dispose();camera.queue_free()
 var file=FileAccess.open("res://evidence/game-flow-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,12),"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"best_score":flow.best_score,"resets":resets}));quit(0 if failures.is_empty() else 1)
