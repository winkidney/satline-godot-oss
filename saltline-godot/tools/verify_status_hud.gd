extends SceneTree
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/status-hud-reference.json"));var failures=[];var comparisons=0
 for index in reference.cases.size():
  var sample=reference.cases[index];var data=sample.data.duplicate(true)
  if data.reserve is String:data.reserve=INF
  var actual=SaltlineStatusHud.snapshot(data)
  for key in sample.expected:
   comparisons+=1
   if actual[key]!=sample.expected[key]:failures.append("%d %s: %s != %s"%[index,key,str(actual[key]),str(sample.expected[key])])
 var report={"cases":reference.cases.size(),"comparisons":comparisons,"failures":failures,"scope":"Actual original HUD ammo/health block; magazine fallback/clamp, counts/reserve/infinity, cue precedence, low/urgent, keyboard/pad/touch text, ceil health/segments and critical thresholds. Pixel layout/transitions separate."}
 var file=FileAccess.open("res://evidence/status-hud-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
