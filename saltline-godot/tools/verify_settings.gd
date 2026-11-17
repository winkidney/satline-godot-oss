extends SceneTree
func _initialize()->void:
 var source=preload("res://scripts/source_settings.gd");var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/settings-reference.json"));var failures=[];var checks=0;var index=0
 for row in fixture.rows:
  var result=source.decode(row.raw)
  for key in row.expected:
   checks+=1
   if result[key]!=row.expected[key]:failures.append([index,key,result[key],row.expected[key]])
  index+=1
 var report={"cases":index,"checks":checks,"failures":failures,"methods_sha256":fixture.methods_sha256,"source_sha256":fixture.source_sha256,"scope":"Original iL settings loader, strict enum types, finite numbers/clamps, JS truthiness, invalid JSON and missing values. Volume excluded by task scope; no disk integration."}
 FileAccess.open("res://evidence/settings-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
