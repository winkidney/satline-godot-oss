extends SceneTree
class ActorStub extends RefCounted:
 signal killed(actor:Variant)
 signal retirement_requested(actor:Variant)
 var state:Dictionary
 var order:Array
 func _init(kind:String,updates:Array)->void:
  order=updates;state={"id":0,"type":kind,"active":false,"alive":false,"pos":Vector3.ZERO,"lastKnown":Vector3.ZERO,"mode":"patrol","modeT":0,"passive":false,"hasToken":false,"sink":0}
 func activate(position:Vector3,options:Dictionary)->void:
  state.active=true;state.alive=true;state.pos=position;state.mode="investigate" if options.get("state")=="alert" else "patrol";state.passive=options.get("passive",false);state.sink=0
 func deactivate()->void:state.active=false;state.alive=false;state.hasToken=false
 func update(dt:float)->void:order.append([state.id,dt])
 func dispose()->void:pass
var order=[]
var alerts=0
var spawns=0
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is Dictionary:
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0001
 return a==b
func ids(actors:Array)->Array:
 var result=[]
 for actor in actors:result.append(actor.state.id)
 return result
func snapshot(manager:SaltlineEnemyManager,result:Variant)->Dictionary:
 var pool=[]
 for kind in ["gull","hound"]:
  for actor in manager.pools[kind]:pool.append(actor.state)
 var coordinator=manager.coordinator
 return {"result":result.state.id if result!=null else null,"active":ids(manager.active),"wrecks":ids(manager.wrecks),"pool":pool,"time":coordinator.time,"playerSpeed":manager.player_speed,"tokens":coordinator.tokens,"tokenTime":coordinator.token_time,"lastType":coordinator.last_type,"want":coordinator.want_times,"nextId":manager.next_id,"alerts":alerts,"spawns":spawns,"order":order}
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/enemy-manager-reference.json"))
 var physics=SaltlinePhysics.new({"boxes":[],"bounds":{}});var player={"velocity":Vector3(3,0,4),"speed":5}
 var coordinator=SaltlineEnemyCoordinator.new(data.modules.enemies.TUNE,physics,player);var combat=SaltlineCombat.new(physics,player);var manager=SaltlineEnemyManager.new(coordinator,combat)
 for i in 2:manager.add_to_pool("gull",ActorStub.new("gull",order))
 for i in 8:manager.add_to_pool("hound",ActorStub.new("hound",order))
 coordinator.tokens=2;coordinator.token_time=17;coordinator.last_type="hound";coordinator.want_times={"gull":4,"hound":5}
 manager.noise_alerted.connect(func(_actor):alerts+=1);manager.spawned.connect(func(_actor):spawns+=1)
 var failures=[]
 for index in reference.operations.size():
  var sample:Dictionary=reference.operations[index];var args:Dictionary=sample.args;var result:Variant=null
  match sample.operation:
   "spawn":result=manager.spawn(args.kind,Vector3(args.pos[0],args.pos[1],args.pos[2]),args.options)
   "kill":
    var actor=manager.pools.hound[int(args.slot)];actor.state.alive=false;manager.add_wreck(actor)
   "retire":manager.retire(manager.pools.hound[int(args.slot)])
   "alert":manager.alert(Vector3(args.pos[0],args.pos[1],args.pos[2]),args.radius)
   "update":manager.update(args.dt)
   "clear":manager.clear()
  var actual=snapshot(manager,result)
  for key in sample.expected:
   if not same(actual[key],sample.expected[key]):failures.append("%d %s %s"%[index,sample.operation,key])
 var report={"failures":failures,"operations":reference.operations.size(),"comparisons":comparisons,"maximum_error":maximum,"scope":reference.scope}
 manager.dispose()
 var file=FileAccess.open("res://evidence/enemy-manager-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
