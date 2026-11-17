extends SceneTree
func code(name:String)->int:
 if name.begins_with("Key"):return name.unicode_at(3)
 if name.begins_with("Digit"):return name.unicode_at(5)
 return {"Space":KEY_SPACE,"ShiftLeft":KEY_SHIFT,"ShiftRight":KEY_SHIFT,"ControlLeft":KEY_CTRL,"ControlRight":KEY_CTRL,"Escape":KEY_ESCAPE,"Numpad1":KEY_KP_1,"Numpad2":KEY_KP_2,"Enter":KEY_ENTER,"NumpadEnter":KEY_KP_ENTER,"ArrowLeft":KEY_LEFT,"ArrowRight":KEY_RIGHT,"ArrowUp":KEY_UP,"ArrowDown":KEY_DOWN}.get(name,0)
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/keyboard-reference.json"));var keyboard=preload("res://scripts/source_keyboard_input.gd").new();var mouse=preload("res://scripts/source_mouse_input.gd").new();var checks=0;var failures=[];var maximum_error=0.0
 for name in reference.mapping:
  checks+=1
  if keyboard.ACTIONS.get(code(name))!=reference.mapping[name]:failures.append("binding "+name)
 for row in reference.rows:
  var op=row.op;var fresh=false
  if op.get("clear",false):keyboard.clear()
  else:fresh=keyboard.key(code(op.code),op.pressed,op.get("repeat",false))
  var held=keyboard.held.keys();held.sort();checks+=2
  if held!=row.expected.held or fresh!=row.expected.fresh:failures.append({"op":op,"held":held,"fresh":fresh,"expected":row.expected})
  mouse.dx=.01;mouse.dy=-.02;var turning=keyboard.turning();mouse.keyboard(turning.x,turning.y,row.dt);var look=mouse.consume()
  for field in ["dx","dy"]:
   checks+=1;var error=absf(look[field]-row.expected.look[field]);maximum_error=maxf(maximum_error,error)
   if not is_finite(error) or error>1e-12:failures.append({"op":op,"look":look})
 var report={"bindings":reference.mapping.size(),"steps":reference.rows.size(),"checks":checks,"maximum_error":maximum_error,"failures":failures,"source_sha256":reference.source_sha256,"methods_sha256":reference.methods_sha256,"scope":"Original fE bindings, keyboard-only v/y action sets and literal keyboard turn block. Repeat suppression, shared aliases/release, clearing and composed look; no GUI target or hardware layout assertion."}
 FileAccess.open("res://evidence/keyboard-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
