extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func compare(actual,expected,context:String)->void:
 if expected is Array:
  for j in expected.size():compare(actual[j],expected[j],context+"/"+str(j))
 else:
  var error=absf(float(actual)-float(expected));checks+=1;maximum=maxf(maximum,error)
  if (not is_finite(float(actual)) or not is_finite(float(expected)) or error>1e-10) and failures.size()<20:failures.append({"context":context,"actual":actual,"expected":expected,"error":error})
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-arm-pose-reference.json"))
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-arm-pose-config.json"));var steps=0
 for case in fixture.cases:
  var module=load("res://scripts/weapon_arm_pose.gd").new(config,case.left)
  for row in case.rows:
   var input=row.input
   module.set_fingers(input.pose);module.set_trigger(input.trigger)
   if input.impulse!=0:module.impulse(input.impulse)
   module.solve(input.shoulder,input.hand,input.rotation,input.pole,.2);module.update(input.dt)
   compare(module.pose,row.expected.pose,str(steps)+"/pose")
   compare(module.shown,row.expected.shown,str(steps)+"/shown")
   compare(module.trigger,row.expected.trigger,str(steps)+"/trigger")
   for j in 35:
    compare(module.bones[j].p,row.expected.bones[j].p,str(steps)+"/bone"+str(j)+"/p")
    compare(module.bones[j].q,row.expected.bones[j].q,str(steps)+"/bone"+str(j)+"/q")
   steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":1e-10,"failures":failures,"source_sha256":fixture.source_sha256,"fh_sha256":fixture.fh_sha256,"scope":"Literal original Fh constructor/methods and finger helpers; real Three Bone hierarchy, mocked geometry/material/Skeleton bind only. Native pose/trigger/impulse/solve/update and all35 local bone p/q. Both sides, float32 finger/spring storage, dt clamp. No production writes/global hierarchy/whole image proof."}
 FileAccess.open("res://evidence/weapon-arm-pose-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
