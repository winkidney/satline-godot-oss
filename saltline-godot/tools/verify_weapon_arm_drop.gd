extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
var draws=0
func vec(a)->Vector3:return Vector3(a[0],a[1],a[2])
func quat(a)->Quaternion:return Quaternion(a[0],a[1],a[2],a[3])
func compare(a,b,context:String)->void:
 if b is Dictionary:
  for key in b:compare(a[key],b[key],context+"/"+key)
 elif b is Array:
  for j in b.size():compare(a[j],b[j],context+"/"+str(j))
 elif b is bool:
  checks+=1
  if a!=b:failures.append(context)
 else:
  checks+=1;var error=absf(float(a)-float(b));maximum=maxf(maximum,error)
  if (not is_finite(float(a)) or error>2e-6) and failures.size()<20:failures.append({"context":context,"actual":a,"expected":b,"error":error})
func _initialize()->void:
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-arm-drop-reference.json"))
 var relaxed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-reload-hand-poses.json")).relaxed
 var module=load("res://scripts/weapon_arm_blend.gd").new();var rng=preload("res://scripts/source_rng.gd").new(4207)
 var random=func():draws+=1;return rng.randf()
 var steps=0
 for row in ref.rows:
  var input=row.input
  if input.reset:module.restore()
  if input.normal:
   var targets=input.targets.duplicate(true)
   for side in ["r","l"]:
    for field in ["p","pole","sh"]:targets[side][field]=vec(targets[side][field])
    targets[side].q=quat(targets[side].q)
   module.update(1.0/60,targets,{"p":vec(input.root.p),"q":quat(input.root.q)})
  if input.start:module.start_drop(random)
  module.drop_update(input.dt,relaxed)
  compare({"r":module.output.r,"l":module.output.l,"visible":module.group_visible,"dropping":module.drop_time>=0,"random_state":rng.state,"random_calls":draws},row.expected,str(steps))
  steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":ref.source_sha256,"stage_sha256":ref.stage_sha256,"scope":ref.scope}
 FileAccess.open("res://evidence/weapon-arm-drop-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
