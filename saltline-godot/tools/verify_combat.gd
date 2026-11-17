extends SceneTree
class CollisionStub extends SaltlinePhysics:
 var wall:Variant=null
 var clear=true
 func _init()->void:super({"boxes":[],"bounds":{}})
 func raycast(origin:Vector3,direction:Vector3,limit:float=500)->Dictionary:
  return {"point":origin+direction*wall,"normal":Vector3.BACK,"dist":wall,"surface":"metal","box":{"id":42}} if wall!=null and wall<=limit else {}
 func line_of_sight(_origin:Vector3,_target:Vector3)->bool:return clear
class PlayerStub extends RefCounted:
 var pos=Vector3(0,0,-5)
 var health=100.0
 var alive=true
 func damage(amount:float,_position:Variant=null)->void:
  health=maxf(0,health-amount)
  if health<=0:alive=false
class ActorStub extends RefCounted:
 signal killed(actor:Variant)
 var state:Dictionary
 var serial=0
 var index:int
 func _init(i:int)->void:index=i;state={"id":i+1,"type":"hound","pos":Vector3(0,0,-5-i*5),"alive":true,"hp":170}
 func raycast(origin:Vector3,direction:Vector3,limit:float,hit:Dictionary)->bool:
  var distance=5+index*5
  if distance>limit or distance>=hit.dist:return false
  hit.dist=distance;hit.point=origin+direction*distance;hit.normal=Vector3.BACK;hit.enemy=state;hit.actor=self;hit.part="weak" if (serial+index)%2 else "body";return true
 func damage(amount:float,_point:Vector3,_direction:Vector3,_part:String)->bool:
  state.hp-=amount
  if state.hp<=0:state.alive=false;killed.emit(self);return true
  return false
var impacts=0
var enemy_events=0
var maximum=0.0
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary:
  if a.size()!=b.size():return false
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array:
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0001
 return a==b
func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/combat-reference.json"))
 var physics=CollisionStub.new();var player=PlayerStub.new();var combat=SaltlineCombat.new(physics,player)
 for i in 3:combat.register_actor(ActorStub.new(i))
 combat.impact.connect(func(_hit):impacts+=1);combat.hit_enemy.connect(func(_enemy,_part,_killed,_weak):enemy_events+=1)
 var failures=[];var fields=0
 for sample in reference.cases:
  physics.wall=sample.wallDistance;physics.clear=sample.clear;player.health=100;player.alive=sample.initialPlayerAlive
  for actor in combat.enemies:actor.state.hp=170;actor.state.alive=true;actor.serial=int(sample.serial)
  combat.enemies[0].state.alive=sample.initialFirstAlive
  var result:Variant=null;var hit:Variant=null
  if sample.mode==0:
   var impact=combat.player_shot(Vector3(0,1,0),vector(sample.direction),sample.damage,100)
   if not impact.is_empty():hit={"dist":impact.dist,"surface":impact.surface,"enemy":impact.enemy.state.id if impact.enemy!=null else null,"part":impact.get("part"),"killed":impact.get("killed",false)}
  elif sample.mode==1:result=combat.enemy_shot(vector(sample.origin),vector(sample.direction),sample.damage,100)
  else:combat.explode(Vector3(0,0,-4),sample.radius,sample.damage,"explosive")
  var hp=[];var alive=[]
  for actor in combat.enemies:hp.append(actor.state.hp);alive.append(actor.state.alive)
  var row={"result":result,"hit":hit,"playerHealth":player.health,"playerAlive":player.alive,"enemyHp":hp,"enemyAlive":alive,"stats":combat.stats,"impacts":impacts,"enemyEvents":enemy_events}
  for key in row:
   fields+=1
   if not same(row[key],sample[key]):failures.append("%s %s"%[sample.serial,key])
 var report={"failures":failures,"cases":reference.cases.size(),"fields":fields,"maximum_error":maximum,"stats":combat.stats.duplicate(),"impacts":impacts,"enemy_events":enemy_events,"scope":reference.scope}
 combat.dispose()
 var file=FileAccess.open("res://evidence/combat-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
