extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-arm-config.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-arm-targets-reference.json"))
 var steps=0
 for case in reference.cases:
  var module=load("res://scripts/weapon_arm_targets.gd").new(data.modules.weapon.rigs,config)
  for row in case.rows:
   var input=row.input
   var left=input.left.duplicate(true);var q=left.q
   left.q=Quaternion(q[0],q[1],q[2],q[3])
   if input.snap:module.snap(case.gun,input.state)
   var actual=module.update(case.gun,input.dt,input.state,input.finger,left,input.stop_weight)
   for side in ["r","l"]:
    for field in ["p","q","pose","pole","sh","trig"]:
     var expected=row.expected[side][field]
     var value=actual[side][field]
     var count=expected.size() if expected is Array else 1
     for channel in count:
      var a=float(value[channel] if count>1 else value)
      var b=float(expected[channel] if count>1 else expected)
      checks+=1;maximum=maxf(maximum,absf(a-b))
      if (not is_finite(a) or not is_finite(b) or absf(a-b)>2e-6) and failures.size()<20:failures.append({"gun":case.gun,"step":steps,"side":side,"field":field,"channel":channel,"actual":a,"expected":b})
   steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":reference.source_sha256,"methods_sha256":reference.methods_sha256,"scope":"Literal original armTargets/snapArms with original exported holds and source config. Explicit synthetic state/finger/stop/left-target inputs. No reload-left trajectory, vS history, Fh IK, production integration or whole image proof."}
 FileAccess.open("res://evidence/weapon-arm-targets-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
