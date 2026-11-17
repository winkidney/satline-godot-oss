extends SceneTree
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/relay-reference.json"));var animation=SaltlineRelayAnimation.new(1)
 var failures=[];var maximum=0.0;var fields=0;var spin=0.0;var door=0.0
 for frame in reference.frames.size():
  if frame==20:animation.set_state("cutting")
  if frame==60:animation.set_state("cut")
  if frame==160:animation.set_state("live")
  if frame==190:animation.set_state("cutting")
  if frame==230:animation.set_state("cut")
  animation.update(.2 if frame==10 else .05);spin+=animation.spin_delta;door-=animation.hinge_delta
  var row={"state":animation.state,"phase":animation.phase,"cutTime":animation.cut_time,"spinSpeed":animation.spin_speed,"hinge":animation.hinge,"hingeVelocity":animation.hinge_velocity,"hingeTarget":animation.hinge_target,"level":animation.level,"color":animation.color_hex,"spin":spin,"door":door}
  for key in row:
   fields+=1
   if row[key] is String:
    if row[key]!=reference.frames[frame][key]:failures.append("%d %s"%[frame,key])
   else:
    var error=absf(float(row[key])-float(reference.frames[frame][key]));maximum=maxf(maximum,error)
    if error>1e-9:failures.append("%d %s"%[frame,key])
 var report={"failures":failures,"frames":reference.frames.size(),"fields":fields,"maximum_error":maximum,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/relay-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
