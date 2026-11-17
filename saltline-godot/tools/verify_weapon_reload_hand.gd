extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var poses=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-reload-hand-poses.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-reload-hand-reference.json"))
 var steps=0
 var integrated=OS.get_cmdline_user_args().has("--integration")
 for case in reference.cases:
  var module=load("res://scripts/weapon_reload_hand.gd").new(data.modules.weapon.rigs,poses)
  var weapon
  if integrated:
   weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
   weapon.current=case.gun;weapon.slots[case.gun].ammo=0 if case.empty else 5
   weapon.slots[case.gun].reserve=100;weapon.reload_now();module=weapon.reload_hand
  var duration=(2.72 if case.empty else 2.24) if case.gun=="rifle" else (1.9 if case.empty else 1.5)
  for row in case.rows:
   var input=row.input;var q=input.root_rotation
   var expected_target=row.expected
   if integrated:
    weapon.magazine_motion.root_rotations[case.gun]=Quaternion(q[0],q[1],q[2],q[3])
    if input.reset:weapon.reset()
    else:
     if not weapon.reload.is_empty():weapon.reload.t=input.time;weapon.reload.fresh=false
     weapon.update(0.0,{"fire":false,"ads":false},{"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false})
     if input.time>=duration:expected_target=case.rows[-1].expected
   elif input.reset:module.reset(case.gun)
   else:module.update(case.gun,input.time,input.empty,Quaternion(q[0],q[1],q[2],q[3]))
   var target=module.targets[case.gun]
   for field in ["p","q","pose"]:
    var actual=target[field];var expected=expected_target[field]
    var sign=1.0
    if field=="q" and actual.dot(Quaternion(expected[0],expected[1],expected[2],expected[3]))<0:sign=-1.0
    for j in expected.size():
     var error=absf(actual[j]*sign-expected[j]);checks+=1;maximum=maxf(maximum,error)
     if (not is_finite(float(actual[j])) or error>2e-6) and failures.size()<30:failures.append({"gun":case.gun,"empty":case.empty,"time":input.time,"field":field,"channel":j,"actual":actual[j],"expected":expected[j],"error":error})
   checks+=1
   if target.busy!=expected_target.busy:failures.append("busy mismatch")
   steps+=1
 var report={"production_integration":integrated,"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":reference.source_sha256,"reload_sha256":reference.reload_sha256,"scope":"Original full reload closures with actual source relaxed/open/mag-pinch poses and exported holds. Dense sequential time and reset; independent native left targets. Production mode additionally uses actual Weapon.update reload event/lifecycle owner and shared magazine. No vS/Fh/whole image proof."}
 FileAccess.open("res://evidence/weapon-reload-hand-integration.json" if integrated else "res://evidence/weapon-reload-hand-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
