extends SceneTree
class SightStub extends "res://scripts/source_physics.gd":
 var clear=true
 func _init()->void:super({"boxes":[],"bounds":{}})
 func line_of_sight(_origin:Vector3,_target:Vector3)->bool:return clear

func make_enemy(id:int,type:String,position:Vector3,alive:bool=true,passive:bool=false)->Dictionary:
 return {"id":id,"type":type,"pos":position,"alive":alive,"passive":passive,"hasToken":false,"sensor":Vector3(position.x,1,position.z),"fwd":Vector3(0,0,1),"senseT":0.0,"los":false,"seeT":0.0,"noSeeT":0.0,"exposure":0.0,"mode":"patrol","modeT":0.0,"lastKnown":Vector3.ZERO,"home":position}

func same(a:Variant,b:Variant)->bool:
 if a is float or a is int:return absf(float(a)-float(b))<.000001
 if a is Vector3:return a.distance_to(Vector3(b[0],b[1],b[2]))<.000001
 if a is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is Dictionary:
  for key in a:
   if not same(a[key],b[key]):return false
  return true
 return a==b

func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/enemy-coordinator-reference.json"))
 var collision=SightStub.new();var player={"alive":true,"pos":Vector3.ZERO,"eye":Vector3(0,1.68,0)}
 var manager=SaltlineEnemyCoordinator.new(data.modules.enemies.TUNE,collision,player)
 for i in 8:manager.list.append(make_enemy(i,"hound" if i%2 else "gull",Vector3(i,0,-8),i<4))
 var failures=[];var fields=0
 for c in reference.tokenCases:
  manager.time=c.time;var id=int(c.id);var result:Variant=null
  if c.operation=="request":result=manager.request_token(manager.list[id])
  elif c.operation=="release":manager.release_token(manager.list[id])
  else:
   for enemy in manager.list:enemy.alive=true
  var flags=[]
  for enemy in manager.list:flags.append(enemy.hasToken)
  var actual={"result":result,"tokens":manager.tokens,"flags":flags,"want":manager.want_times,"lastType":manager.last_type}
  for key in actual:
   fields+=1
   if not same(actual[key],c[key]):failures.append("token %s %s"%[c.time,key])
 manager=SaltlineEnemyCoordinator.new(data.modules.enemies.TUNE,collision,player)
 manager.list=[make_enemy(1,"hound",Vector3(0,0,-8)),make_enemy(2,"gull",Vector3(4,0,-8)),make_enemy(3,"hound",Vector3(-3,0,-8),true,true)]
 for frame in reference.perception.size():
  manager.time=float(frame+1)*.05;collision.clear=frame<20;player.alive=frame<120 or frame>=180
  var enemy:Dictionary=manager.list[0]
  if frame==15:enemy.hasToken=true;manager.tokens=1
  if frame==180:manager.provoke(enemy)
  if frame==280:enemy.mode="investigate";enemy.modeT=.1
  manager.think(enemy,.05,.35)
  var expected:Dictionary=reference.perception[frame]
  for key in ["mode","modeT","los","senseT","seeT","noSeeT","exposure","lastKnown","home","hasToken"]:
   fields+=1
   if not same(enemy[key],expected[key]):failures.append("perception %d %s"%[frame,key])
  if manager.tokens!=expected.tokens or manager.list[1].mode!=expected.neighborMode or not same(manager.list[1].modeT,expected.neighborTime) or manager.list[2].mode!=expected.passiveMode:failures.append("rally or token release %d"%frame)
 var report={"failures":failures,"token_cases":reference.tokenCases.size(),"perception_frames":reference.perception.size(),"fields_compared":fields,"scope":"Original methods with controlled LOS and fresh independent su(9001), not full AI simulation"}
 var file=FileAccess.open("res://evidence/enemy-coordinator-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first_failures":failures.slice(0,8),"fields":fields,"perception_frames":reference.perception.size()}));quit(0 if failures.is_empty() else 1)
