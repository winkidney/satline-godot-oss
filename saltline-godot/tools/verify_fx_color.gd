extends SceneTree
func _initialize()->void:
 var parser=preload("res://scripts/fx_color.gd").new()
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/fx-color-reference.json"))
 var failures=[];var checks=0;var maximum=0.0
 for row in reference.rows:
  var actual=parser.parse(row.input)
  for i in 3:
   checks+=1;var error=absf(actual[i]-float(row.expected[i]));maximum=maxf(maximum,error)
   if error>1e-12:failures.append({"input":row.input,"channel":i,"error":error})
 var result={"checks":checks,"cases":reference.rows.size(),"maximum_error":maximum,"failures":failures}
 var file=FileAccess.open("res://evidence/fx-color-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
