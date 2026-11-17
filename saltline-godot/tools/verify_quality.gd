extends SceneTree
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/quality-reference.json"));var script=preload("res://scripts/render_quality.gd");var failures=[];var checks=0
 for name in reference.presets:
  for field in reference.presets[name]:
   checks+=1
   if script.PRESETS[name][field]!=reference.presets[name][field]:failures.append(name+"/"+field)
 for row in reference.rows:
  checks+=1
  var actual=script.resolution(Vector2i(row.screen[0],row.screen[1]),script.PRESETS[row.name],row.dpr,row.drs)
  if actual!=Vector2i(row.size[0],row.size[1]):failures.append({"case":row,"actual":[actual.x,actual.y]})
 var report={"checks":checks,"resolution_cases":reference.rows.size(),"failures":failures,"source_sha256":reference.source_sha256,"methods_sha256":reference.methods_sha256,"scope":"Original five presets and actual original render.resize method, viewport/DPR/DRS scale and pixel cap. Pure sizing formula; native runtime DPR mapping and adaptive controller are verified separately."}
 FileAccess.open("res://evidence/quality-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
