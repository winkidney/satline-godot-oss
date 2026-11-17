extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/rain-initialization.json"))
 var failures=[];var samples=[];var components=0
 for case in fixture.cases:
  var actual=preload("res://scripts/rain_initialization.gd").generate(int(case.seed),float(case.scale))
  for name in ["rain","splash"]:
   var expected=FileAccess.get_file_as_bytes("res://assets/export/"+case.files[name])
   if actual[name].to_byte_array()!=expected:failures.append(case.quality+" "+name+" float32 bytes")
   components+=actual[name].size()
  for key in ["drops","splashes","calls","state"]:
   if actual[key]!=case[key]:failures.append(case.quality+" "+key)
  if absf(actual.thunder_timer-case.thunder_timer)>1e-12:failures.append(case.quality+" timer")
  samples.append({"quality":case.quality,"calls":actual.calls,"state":actual.state,"timer":actual.thunder_timer})
 var report={"failures":failures,"cases":samples,"float32_components":components,"scope":fixture.scope}
 FileAccess.open("res://evidence/rain-initialization-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
