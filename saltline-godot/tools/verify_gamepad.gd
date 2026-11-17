extends SceneTree
var queries=0
var target=false
func query()->bool:queries+=1;return target
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/gamepad-reference.json"));var pad=preload("res://scripts/source_gamepad_input.gd").new();var failures=[];var checks=0;var maximum_error=0.0
 for row in fixture.rows:
  var op=row.op
  if op.has("device"):pad.device=op.device
  if op.has("assist"):pad.assist=op.assist
  pad.poll(op.pad,op.dt,op.gameplay,op.prompt,op.now,op.sensitivity,op.invert,op.external)
  if op.assist_update:target=op.enemy and not op.blocked;pad.update_assist(op.dt,pad.device=="pad",query)
  var actual={"held":pad.held.keys(),"pressed":pad.pressed.keys(),"ui":pad.ui.duplicate(),"move":pad.move,"look":pad.look,"connected":pad.connected,"device":pad.device,"acceleration":pad.acceleration,"sprint_latch":pad.sprint_latch,"context":pad.context,"previous_buttons":Array(pad.previous_buttons),"menu_vertical":pad.menu_vertical,"menu_repeat":pad.menu_repeat,"menu_horizontal":pad.menu_horizontal,"assist":pad.assist,"assist_state":{"time":pad.assist_time,"target":pad.assist_target},"queries":queries}
  actual.held.sort();actual.pressed.sort();actual.ui.sort()
  for field in actual:
   checks+=1;var a=actual[field];var expected=row.expected[field]
   if typeof(a)==TYPE_FLOAT:
    var error=absf(a-expected);maximum_error=maxf(maximum_error,error)
    if not is_finite(error) or error>1e-10:failures.append({"field":field,"op":op,"actual":a,"expected":expected})
   elif field in ["move","look"]:
    for i in 2:
     checks+=1;var error=absf(a[i]-expected[i]);maximum_error=maxf(maximum_error,error)
     if not is_finite(error) or error>1e-10:failures.append({"field":field,"op":op,"actual":a,"expected":expected})
   elif field=="previous_buttons":
    for i in 20:
     checks+=1
     if a[i]!=expected[i]:failures.append("button history")
   elif field=="assist_state":
    for key in ["time","target"]:
     checks+=1;var error=absf(a[key]-expected[key]);maximum_error=maxf(maximum_error,error)
     if not is_finite(error) or error>1e-10:failures.append("assist state")
   elif a!=expected:failures.append({"field":field,"op":op,"actual":a,"expected":expected})
 var report={"steps":fixture.rows.size(),"checks":checks,"maximum_error":maximum_error,"failures":failures.slice(0,30),"failure_count":failures.size(),"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":"Literal original input re/X/v, deadzones/buttons/menu repeat/context/sprint/look and original GameFlow B aim assist with controlled enemy/occlusion callbacks. No actual controller or native menu/physics parity claim."}
 FileAccess.open("res://evidence/gamepad-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
