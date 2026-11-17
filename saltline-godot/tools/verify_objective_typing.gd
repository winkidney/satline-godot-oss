extends SceneTree
func _initialize()->void:
 var hud=preload("res://scripts/objective_hud.gd").new();var rows=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/objective-typing-reference.json"));var failures=[]
 for i in rows.size():
  var row=rows[i];hud.update_frame(row.dt,row.value,0,3)
  if hud.characters!=int(row.characters) or hud.text.left(hud.characters)!=row.text:failures.append(i)
 var report={"frames":rows.size(),"checks":rows.size()*2,"failures":failures,"scope":"Original typewriter update block vs production objective HUD, zero dt, large dt and objective reset; no layout/pixel proof."}
 FileAccess.open("res://evidence/objective-typing-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));hud.free();quit(0 if failures.is_empty() else 1)
