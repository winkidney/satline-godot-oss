extends SceneTree
func vector(value:Array)->Vector3:return Vector3(value[0],value[1],value[2])
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/enemy-hit-shapes-reference.json"))
 var state:Dictionary=reference.state;state.pos=vector(state.pos);state.headPos=vector(state.headPos)
 var failures=[];var maximum=0.0;var hits=0;var weak=0
 for i in reference.cases.size():
  var sample:Dictionary=reference.cases[i];var hit={"dist":sample.prior,"point":Vector3.ZERO,"normal":Vector3.ZERO,"part":null}
  var found=SaltlineEnemyHitShapes.hound(state,vector(sample.origin),vector(sample.direction),sample.limit,hit)
  var error=maxf(absf(hit.dist-sample.dist),maxf(hit.point.distance_to(vector(sample.point)),hit.normal.distance_to(vector(sample.normal))))
  maximum=maxf(maximum,error)
  if found!=sample.found or hit.part!=sample.part or error>.001:failures.append(i)
  if found:hits+=1;weak+=int(hit.part=="weak")
 var report={"failures":failures,"cases":reference.cases.size(),"hits":hits,"weak":weak,"maximum_error":maximum,"numeric_tolerance":.001,"precision_note":"Vector3 inputs are float32; near-parallel axis rays amplify rounding, all hit and part decisions must match","scope":reference.scope}
 var file=FileAccess.open("res://evidence/enemy-hit-shapes-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
