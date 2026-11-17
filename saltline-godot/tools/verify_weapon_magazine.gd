extends SceneTree
var failures=[]
var maximum=0.0
var comparisons=0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-magazine-reference.json"));var steps=0
 for sample in reference.cases:
  var motion=load("res://scripts/weapon_magazine_motion.gd").new(data.modules.weapon.rigs)
  for index in sample.rows.size():
   var row=sample.rows[index].input
   var q=row.root_rotation;motion.root_rotations[sample.gun]=Quaternion(q[0],q[1],q[2],q[3])
   if row.reset:motion.reset(sample.gun)
   else:motion.update(sample.gun,row.time)
   var tr:Transform3D=motion.poses[sample.gun]
   var matrix=[tr.basis.x.x,tr.basis.x.y,tr.basis.x.z,0,tr.basis.y.x,tr.basis.y.y,tr.basis.y.z,0,tr.basis.z.x,tr.basis.z.y,tr.basis.z.z,0,tr.origin.x,tr.origin.y,tr.origin.z,1]
   for channel in 16:
    comparisons+=1
    var error=absf(matrix[channel]-sample.rows[index].expected.matrix[channel]);maximum=maxf(maximum,error)
    if (not is_finite(float(matrix[channel])) or error>2e-6) and failures.size()<20:failures.append({"gun":sample.gun,"empty":sample.empty,"step":index,"time":row.time,"channel":channel,"error":error})
   steps+=1
 var lifecycle_checks=0
 for sample in reference.cases:
  for at in [.6,1.6 if sample.gun=="rifle" else 1.2]:
   var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
   weapon.current=sample.gun
   weapon.slots[sample.gun].ammo=0 if sample.empty else 5
   weapon.slots[sample.gun].reserve=100
   var player={"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
   var input={"fire":false,"ads":false}
   if not weapon.reload_now():failures.append("reload did not start")
   weapon.update(0.0,input,player)
   weapon.update(at,input,player)
   weapon.switch_to("pistol" if sample.gun=="rifle" else "rifle")
   var tr:Transform3D=weapon.magazine_motion.poses[sample.gun]
   var matrix=[tr.basis.x.x,tr.basis.x.y,tr.basis.x.z,0,tr.basis.y.x,tr.basis.y.y,tr.basis.y.z,0,tr.basis.z.x,tr.basis.z.y,tr.basis.z.z,0,tr.origin.x,tr.origin.y,tr.origin.z,1]
   var expected=sample.rows[-1].expected.matrix
   for channel in 16:
    lifecycle_checks+=1
    if not is_finite(float(matrix[channel])) or not is_finite(float(expected[channel])) or absf(matrix[channel]-expected[channel])>2e-6:failures.append({"cancel_gun":sample.gun,"at":at,"channel":channel})
   if not weapon.reload.is_empty():failures.append("switch retained reload")
 var report={"lifecycle_channels":lifecycle_checks,"cases":reference.cases.size(),"steps":steps,"matrix_channels":comparisons,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":reference.source_sha256,"reload_sha256":reference.reload_sha256,"scope":reference.scope+" Native float32 magazine Transform3D only; production renderer/controller wiring separately verified."}
 FileAccess.open("res://evidence/weapon-magazine-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
