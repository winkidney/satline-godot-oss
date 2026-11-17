extends SceneTree
var pose_count=0
var retired_count=0
var killed_count=0
var lens=Vector3.ZERO
var effects=[]
var maximum_error=0.0
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
  var error=absf(float(a)-float(b));maximum_error=maxf(maximum_error,error);return error<.0001
 return a==b
func snapshot(state:Dictionary)->Dictionary:
 var row=state.duplicate(true);row.merge({"poseCount":pose_count,"retired":retired_count,"killed":killed_count,"lens":lens},true);return row
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hound-life-reference.json"))
 var state:Dictionary=reference.input.duplicate(true)
 for key in ["pos","headPos"]:state[key]=Vector3(state[key][0],state[key][1],state[key][2])
 for foot in state.feet:
  for key in ["p","slide"]:foot[key]=Vector3(foot[key][0],foot[key][1],foot[key][2])
 var manager=SaltlineEnemyCoordinator.new(data.modules.enemies.TUNE,SaltlinePhysics.new({"boxes":[],"bounds":{}}),null);manager.tokens=1
 var life=SaltlineHoundLife.new(state,manager)
 life.pose_requested.connect(func(_dt):pose_count+=1)
 life.killed.connect(func():killed_count+=1)
 life.retired.connect(func():retired_count+=1;state.active=false)
 life.lens_requested.connect(func(color):lens=color)
 life.effect_requested.connect(func(kind,position,options):effects.append({"kind":kind,"position":position,"options":options}))
 var failures=[]
 for i in reference.damageCases.size():
  var sample:Dictionary=reference.damageCases[i];var direction=Vector3(sample.direction[0],sample.direction[1],sample.direction[2])
  if life.damage(sample.amount,state.headPos,direction,sample.part)!=reference.damageResults[i]:failures.append("damage %d"%i)
 if not same(snapshot(state),reference.death):failures.append("death")
 for frame in reference.frames.size():
  if frame==720:state.sink=.001
  life.update(1.0/60)
  if not same(snapshot(state),reference.frames[frame]):failures.append("frame %d"%frame)
 if not same(effects,reference.effects):failures.append("effects")
 if not same(manager.rng.randf(),reference.nextRandom):failures.append("random consumption")
 var report={"failures":failures,"frames":reference.frames.size(),"effects":effects.size(),"comparisons":comparisons,"maximum_error":maximum_error,"retired":retired_count,"killed":killed_count,"pose_updates":pose_count,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/hound-life-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
