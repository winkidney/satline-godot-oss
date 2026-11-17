extends SceneTree
func _initialize()->void:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-smoke-reference.json"))
 var weapon=SaltlineWeapon.new(source.modules.weapon);var requests=[];var receiver=func(options):requests.append(options.duplicate(true))
 weapon.smoke_requested.connect(receiver)
 var failures=[];var checks=0;var maximum=0.0
 var player={"alive":true,"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
 for i in fixture.rows.size():
  var row=fixture.rows[i];var op=row.op;var expected=row.expected;requests.clear()
  if op.get("reset",false):weapon.reset()
  else:
   if op.has("time_before"):weapon.time=float(op.time_before)
   if op.has("last_shot"):weapon.last_shot=float(op.last_shot)
   if op.has("heat"):weapon.heat=float(op.heat)
   for key in ["smoke","smokeTick"]:
    if op.has(key):weapon.motion_state[key]=float(op[key])
   if op.has("gun"):weapon.current=op.gun
   if op.has("available"):
    if not op.available and weapon.smoke_requested.is_connected(receiver):weapon.smoke_requested.disconnect(receiver)
    elif op.available and not weapon.smoke_requested.is_connected(receiver):weapon.smoke_requested.connect(receiver)
   weapon.update(float(op.dt),{"fire":false,"ads":false},player)
  var actual={"t":weapon.time,"heat":weapon.heat,"smoke":weapon.motion_state.smoke,"smokeTick":weapon.motion_state.smokeTick}
  for key in actual:
   checks+=1;var error=abs(float(actual[key])-float(expected[key]));maximum=maxf(maximum,error)
   if not is_finite(error) or error>1e-11:failures.append({"step":i,"field":key,"actual":actual[key],"expected":expected[key],"error":error})
  checks+=1
  if requests.size()!=expected.requests.size():failures.append({"step":i,"request_count":requests.size(),"expected":expected.requests.size()})
  for j in mini(requests.size(),expected.requests.size()):
   for key in expected.requests[j]:
    checks+=1;var error=abs(float(requests[j][key])-float(expected.requests[j][key]));maximum=maxf(maximum,error)
    if not is_finite(error) or error>1e-11:failures.append({"step":i,"request":key,"error":error})
 var report={"steps":fixture.rows.size(),"checks":checks,"maximum_error":maximum,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":fixture.scope+" Actual Native Weapon.update + smoke_requested callback/options."}
 FileAccess.open("res://evidence/weapon-smoke-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
