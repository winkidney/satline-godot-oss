extends SceneTree
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/touch-reference.json"));var touch=preload("res://scripts/source_touch_input.gd").new();var step=0
 for row in fixture.rows:
  var op=row.op;touch.end_frame()
  match op.type:
   "start":touch.start(int(op.id),op.x,op.y,1280,true)
   "motion":touch.motion(int(op.id),op.x,op.y,op.get("sensitivity",1),op.get("invert",false))
   "finish":touch.finish(int(op.id))
   "button":touch.button(op.action,int(op.id),op.on,op.get("x",0),op.get("y",0))
   "clear":touch.clear()
  var actual={"move":touch.move,"look":touch.look,"sprint":touch.sprint(),"ads":touch.ads,"held":touch.held.keys(),"pressed":touch.pressed.keys()}
  for key in row.expected:
   checks+=1;var a=actual[key];var b=row.expected[key]
   if key in ["move","look"]:
    for i in 2:
     var error=absf(a[i]-b[i]);maximum_error=maxf(maximum_error,error)
     if not is_finite(error) or error>1e-12:failures.append([step,key,i,a[i],b[i]])
   elif key in ["held","pressed"]:
    a.sort();b.sort()
    if a!=b:failures.append([step,key,a,b])
   elif a!=b:failures.append([step,key,a,b])
  step+=1
 var report={"checks":checks,"steps":step,"maximum_error":maximum_error,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":"Literal original gE touch DOM event handlers with stub DOM and navigator; movement, look, sprint, button holds/edges, ADS toggle, fire drag, ownership and blur. No native routing or touch hardware acceptance."}
 FileAccess.open("res://evidence/touch-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
