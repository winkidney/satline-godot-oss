extends SceneTree
class PhysicsStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func line_of_sight(origin:Vector3,_target:Vector3)->bool:return origin.x<15
 func ground_height(_x:float,_z:float,_y:float=0)->float:return 0
class NavStub extends SaltlineNavigation:
 var sample_index=0
 func is_walkable(x:float,z:float)->bool:return absf(x)<29 and absf(z)<29
 func random_point(origin:Vector3,_radius:float)->Vector3:
  var angle=(sample_index%7)*.8;sample_index+=1
  return Vector3(origin.x+cos(angle)*12,0,origin.z+sin(angle)*12)
 func find_path(_start:Vector3,goal:Vector3)->Variant:return [goal]
class ManagerStub extends SaltlineEnemyCoordinator:
 func think(_enemy:Dictionary,_dt:float,_delay:float)->void:pass
 func request_token(enemy:Dictionary)->bool:enemy.hasToken=true;return true
 func release_token(enemy:Dictionary)->void:enemy.hasToken=false
var shots=0
var melee=0
var telegraphs=0
var maximum_error=0.0
func same(actual:Variant,expected:Variant)->bool:
 if actual is Vector3:return same([actual.x,actual.y,actual.z],expected)
 if actual is Array:
  for i in actual.size():
   if not same(actual[i],expected[i]):return false
  return true
 if actual is float or actual is int:
  var error=absf(float(actual)-float(expected));maximum_error=maxf(maximum_error,error);return error<.0001
 return actual==expected
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hound-behavior-reference.json"))
 var collision=PhysicsStub.new();var nav=NavStub.new(collision)
 var player={"pos":Vector3(0,0,12),"eye":Vector3(0,1.68,12),"alive":true}
 var manager=ManagerStub.new(data.modules.enemies.TUNE,collision,player)
 var state={"id":1,"type":"hound","active":true,"alive":true,"pos":Vector3.ZERO,"headPos":Vector3(0,1,0),"fwd":Vector3.ZERO,"sensor":Vector3.ZERO,"goal":Vector3.ZERO,"firePos":Vector3.ZERO,"firePlayer":Vector3.ZERO,"lastKnown":Vector3(0,0,4),"home":Vector3.ZERO,"hasGoal":false,"path":null,"wp":0,"planT":0,"stuckT":0,"yaw":0,"wantYaw":0,"speed":0,"maxSpeed":0,"cool":0,"lungeCd":0,"mode":"engage","modeSeen":"engage","es":"aim","esT":0,"moveT":0,"bursts":0,"shots":0,"tyaw":0,"los":true,"noSeeT":0,"flare":0,"sP":{"v":0},"waitT":0,"scan":0,"patrolR":8,"patrolLine":null,"hasToken":false}
 manager.list=[state,{"id":2,"type":"hound","alive":true,"mode":"engage","es":"move","pos":Vector3(9,0,7),"firePos":Vector3(10,0,8)}]
 var movement=SaltlineHoundLocomotion.new(state,nav,data.modules.enemies.TUNE.hound,manager.rng)
 var behavior=SaltlineHoundBehavior.new(state,movement,manager,[Vector3.ZERO,Vector3(10,0,8),Vector3(-9,0,5),Vector3(20,0,10)])
 behavior.shot_requested.connect(func():shots+=1)
 behavior.melee_requested.connect(func(_damage,_position):melee+=1)
 behavior.telegraph.connect(func(_duration,_melee):telegraphs+=1)
 var failures=[];var fields=0
 for i in reference.selections.size():
  behavior.select_fire_position()
  for key in reference.selections[i]:
   fields+=1
   if not same(state[key],reference.selections[i][key]):failures.append("selection %d %s"%[i,key])
 for frame in reference.frames.size():
  if frame%150==0:
   state.es="aim";state.esT=0;state.cool=0;state.lungeCd=0;state.mode="engage";state.modeSeen="engage";player.pos=Vector3(0,0,1 if frame%300==0 else 12);state.yaw=0;state.tyaw=0;state.los=true
  if frame==600:state.mode="investigate";state.modeSeen="investigate";state.lastKnown=Vector3(0,0,1)
  if frame==750:state.mode="patrol";state.modeSeen="patrol";state.hasGoal=false
  manager.time+=1.0/60;behavior.decide(1.0/60)
  var actual={"crouch":behavior.crouch_target,"lunging":behavior.lunging,"shots":shots,"melee":melee,"telegraphs":telegraphs,"spring":state.sP.v}
  for key in reference.frames[frame]:
   fields+=1
   var value=actual[key] if actual.has(key) else state[key]
   if not same(value,reference.frames[frame][key]):failures.append("frame %d %s"%[frame,key])
 state.crouch=0;state.sY={"x":0};state.phase=.37;state.yawRate=.3;state.tpitch=0;state.hyaw=0;state.hpitch=0;state.tyaw=0
 for frame in reference.aimFrames.size():
  manager.time=float(frame)/60;state.yaw=sin(frame*.02)
  behavior.turret_target=Vector3(4,0,8) if frame<120 else null;behavior.head_target=Vector3(-2,0,3) if frame<60 else null;behavior.crouch_target=.16 if frame<90 else 0
  behavior.aim(1.0/60)
  for key in reference.aimFrames[frame]:
   fields+=1
   if not same(state[key],reference.aimFrames[frame][key]):failures.append("aim %d %s"%[frame,key])
 var report={"failures":failures,"fields_compared":fields,"selections":reference.selections.size(),"frames":reference.frames.size(),"aim_frames":reference.aimFrames.size(),"maximum_error":maximum_error,"shots":shots,"melee":melee,"telegraphs":telegraphs,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/hound-behavior-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify({"failures":failures.size(),"first_failures":failures.slice(0,12),"fields":fields,"maximum_error":maximum_error,"shots":shots,"melee":melee,"telegraphs":telegraphs}));quit(0 if failures.is_empty() else 1)
