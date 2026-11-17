extends SceneTree
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sight-environment-reference.json"))
 var model=SaltlineSightEnvironment.new();var failures=[];var max_error=0.0
 for index in reference.frames.size():
  var row=reference.frames[index];var value=model.update(row.intensity)
  var error=maxf(absf(value-row.value),absf(model.peak-row.peak));max_error=maxf(max_error,error)
  if error>1e-12:failures.append(index)
 var report={"frames":reference.frames.size(),"comparisons":reference.frames.size()*2,"failures":failures,"maximum_error":max_error,"scope":"Actual original ME onBeforeRender callback: peak environment history, zero intensity fallback, target clamp and per-render 0.12 smoothing. Native full world indoor adaptation input remains pending."}
 var file=FileAccess.open("res://evidence/sight-environment-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
