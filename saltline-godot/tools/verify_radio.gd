extends SceneTree
var started=[]
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/radio-reference.json"))
 var radio=SaltlineRadio.new();radio.line_started.connect(func(text):started.append(text))
 var failures=[];var max_error=0.0;var comparisons=0
 for index in reference.frames.size():
  var frame=reference.frames[index]
  for action in frame.actions:
   if action.type=="clear":radio.clear()
   else:radio.enqueue(action.text,action.secs)
  radio.update(frame.dt)
  var actual={"text":radio.text,"visible":radio.visible,"cursor":radio.cursor,"typed":radio.typed,"remaining":radio.remaining,"current":null if radio.current.is_empty() else radio.current,"queue":radio.queue,"started":started}
  for key in actual:
   comparisons+=1
   if key in ["typed","remaining"]:
    var error=absf(actual[key]-frame[key]);max_error=maxf(max_error,error)
    if error>1e-9:failures.append("%d %s"%[index,key])
   elif actual[key]!=frame[key]:failures.append("%d %s"%[index,key])
 var report={"frames":reference.frames.size(),"comparisons":comparisons,"failures":failures,"maximum_error":max_error,"started_lines":started.size(),"scope":"Actual original HUD Y function against native queue, clear, typing and hold timing with variable dt; includes queued transitions, zero-duration line and reset replacement"}
 var file=FileAccess.open("res://evidence/radio-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
