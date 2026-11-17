extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func compare(a,b,context:String)->void:
 if b is Array:
  for j in b.size():compare(a[j],b[j],context+"/"+str(j))
 else:
  var error=absf(float(a)-float(b));checks+=1;maximum=maxf(maximum,error)
  if (not is_finite(float(a)) or not is_finite(float(b)) or error>1e-10) and failures.size()<20:failures.append({"context":context,"actual":a,"expected":b,"error":error})
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-arm-ik-reference.json"));var steps=0
 for case in reference.cases:
  var module=load("res://scripts/weapon_arm_ik.gd").new(case.left)
  for row in case.rows:
   var input=row.input
   var actual=module.solve(input.shoulder,input.hand,input.rotation,input.pole,input.lean)
   for field in row.expected:compare(actual[field],row.expected[field],str(steps)+"/"+field)
   steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":1e-10,"failures":failures,"source_sha256":reference.source_sha256,"solver_sha256":reference.solver_sha256,"scope":"Literal original Fh.L with original Three math; both sides, reach/lean limits, degenerate targets/poles, wrist diagnostics, five local rotations and history displacement. Native double-array core; no finger/spring/bone writing/production/whole image proof."}
 FileAccess.open("res://evidence/weapon-arm-ik-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
