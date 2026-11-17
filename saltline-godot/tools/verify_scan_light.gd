extends SceneTree
class CollisionStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func raycast(origin:Vector3,direction:Vector3,limit:float=500)->Dictionary:
  if direction.y>=0:return {}
  var distance=-origin.y/direction.y
  return {"dist":distance} if distance<=limit else {}
class ActorStub extends RefCounted:
 var state:Dictionary
 func _init(record:Dictionary)->void:state=record
class EmptyPool extends SaltlineLightPool:
 var attempts=0
 func acquire()->Dictionary:attempts+=1;return {}
var maximum=0.0
var comparisons=0
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
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/scan-light-reference.json"))
 var physics=CollisionStub.new();var controller=SaltlineGullScanLight.new(physics);controller.position=Vector3(1,2,3)
 var actors=[ActorStub.new({"id":1,"type":"gull","alive":true,"pos":Vector3(0,4,0),"sensor":Vector3(0,3.83,.27),"yaw":.3,"gy":.1,"gp":.4}),ActorStub.new({"id":2,"type":"gull","alive":true,"pos":Vector3(5,6,3),"sensor":Vector3(5,5.83,3.27),"yaw":-.4,"gy":.2,"gp":.1}),ActorStub.new({"id":3,"type":"hound","alive":true,"pos":Vector3.ZERO})]
 var failures=[]
 for frame in reference.frames.size():
  var sample:Dictionary=reference.frames[frame];actors[0].state.alive=sample.firstAlive;actors[0].state.gp=sample.firstPitch;actors[1].state.gp=sample.secondPitch
  if frame==180:controller.clear()
  controller.update(1.0/60,actors,Vector3(sample.camera[0],sample.camera[1],sample.camera[2]))
  var row={"energy":controller.energy,"position":controller.position,"timer":controller.timer,"target":controller.target,"gain":controller.hit_gain}
  for key in row:
   if not same(row[key],sample[key]):failures.append("%d %s"%[frame,key])
 var pool=EmptyPool.new();var unavailable=SaltlineGullScanLight.new(physics,pool)
 for i in 10:unavailable.update(1.0/60,actors,Vector3.ZERO)
 if pool.attempts!=1:failures.append("acquire retries")
 unavailable.dispose();pool.free()
 var report={"failures":failures,"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"failed_acquire_attempts":1,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/scan-light-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,8),"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum}));quit(0 if failures.is_empty() else 1)
