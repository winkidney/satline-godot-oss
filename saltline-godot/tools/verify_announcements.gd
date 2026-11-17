extends SceneTree
func _initialize()->void:
 var script=preload("res://scripts/announcements_hud.gd");var failures=[];var checks=0;var maximum_error=0.0
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/warning-css-reference.json"))
 for row in fixture.rows:
  var style=script.warning_style(row.seconds)
  for pair in [[style.alpha,row.alpha],[style.spacing_em*row.pixels,row.spacing]]:
   checks+=1;var error=absf(pair[0]-pair[1]);maximum_error=maxf(maximum_error,error)
   if error>.0001:failures.append({"sample":row,"error":error})
 var timers=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/announcement-timer-reference.json"));var hud=script.new()
 for row in timers.rows:
  var op=row.op
  if op.kind=="warn":hud.warn(op.text,op.duration)
  elif op.kind=="message":hud.show_message(op.text,op.duration)
  else:hud.update_frame(op.dt,op.on)
  for field in row.expected:
   checks+=1
   if hud.get(field)!=row.expected[field]:
    if field.ends_with("remaining") and absf(hud.get(field)-row.expected[field])<1e-10:continue
    failures.append({"field":field,"expected":row.expected[field],"actual":hud.get(field)})
 var report={"checks":checks,"css_samples":fixture.rows.size(),"timer_steps":timers.rows.size(),"maximum_css_error":maximum_error,"failures":failures,"source_sha256":timers.source_sha256,"methods_sha256":timers.methods_sha256,"scope":"Browser original CSS warning opacity/spacing, literal original warning/message methods and timer block; HUD gate, zero/negative duration quirks. No glyph pixel comparison."}
 FileAccess.open("res://evidence/announcements-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));hud.free();quit(0 if failures.is_empty() else 1)
