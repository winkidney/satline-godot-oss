extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func vector(a)->Vector3:return Vector3(a[0],a[1],a[2])
func quaternion(a)->Quaternion:return Quaternion(a[0],a[1],a[2],a[3])
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-arm-blend-reference.json"))
 var module=load("res://scripts/weapon_arm_blend.gd").new()
 var steps=0
 for row in fixture.rows:
  var input=row.input
  if input.action!=null:
   var a=input.action
   match a.kind:
    "blend":module.blend(a.duration)
    "snap":module.snap()
    "attach":module.attach({"p":vector(a.offset.p),"q":quaternion(a.offset.q)} if a.offset!=null else {})
  var targets=input.targets.duplicate(true)
  for side in ["r","l"]:
   for field in ["p","pole","sh"]:targets[side][field]=vector(targets[side][field])
   targets[side].q=quaternion(targets[side].q)
  var result=module.update(input.dt,targets,{"p":vector(input.root.p),"q":quaternion(input.root.q)})
  for side in ["r","l"]:
   for field in ["p","q","pole","sh","pose","trig","lean"]:
    var expected=row.expected[side][field];var actual=result[side][field]
    var count=expected.size() if expected is Array else 1
    var sign=-1.0 if field=="q" and actual.dot(quaternion(expected))<0 else 1.0
    for j in count:
     var a=float(actual[j] if count>1 else actual)*sign
     var b=float(expected[j] if count>1 else expected)
     var error=absf(a-b);maximum=maxf(maximum,error);checks+=1
     if (not is_finite(a) or not is_finite(b) or error>2e-6) and failures.size()<20:failures.append({"step":steps,"side":side,"field":field,"channel":j,"actual":a,"expected":b,"error":error})
  steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":fixture.source_sha256,"stage_sha256":fixture.stage_sha256,"scope":fixture.scope}
 FileAccess.open("res://evidence/weapon-arm-blend-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
