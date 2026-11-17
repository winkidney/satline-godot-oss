extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/interaction-reference.json"));var hud=preload("res://scripts/interaction_hud.gd").new();var failures=[];var checks=0
 for row in fixture.rows:
  var op=row.op;var key="USE" if op.get("device")=="touch" else "X" if op.get("device")=="pad" else "E"
  hud.set_prompt(op.value,op.t,key)
  for field in ["active","key","text","progress","dash_offset"]:
   checks+=1
   if field in ["progress","dash_offset"]:
    if absf(hud.get(field)-row.expected[field])>1e-10:failures.append({"field":field,"actual":hud.get(field),"expected":row.expected[field]})
   elif hud.get(field)!=row.expected[field]:failures.append({"field":field,"actual":hud.get(field),"expected":row.expected[field]})
  checks+=2
  if (hud.progress>0)!=row.expected.busy or (hud.key.length()>1)!=row.expected.wide:failures.append("busy/wide")
 var report={"steps":fixture.rows.size(),"checks":checks,"failures":failures,"source_sha256":fixture.source_sha256,"method_sha256":fixture.method_sha256,"scope":"Original setPrompt state, key/label retention on hide, progress quantization, SVG offset rounding and keyboard/pad/touch labels. Native actual device routing and pixels not asserted."}
 FileAccess.open("res://evidence/interaction-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));hud.free();quit(0 if failures.is_empty() else 1)
