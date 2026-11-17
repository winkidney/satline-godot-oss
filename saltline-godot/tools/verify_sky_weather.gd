extends SceneTree
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sky-weather-reference.json"));var model=SaltlineSkyWeather.new();var failures=[];var maximum=0.0
 for index in reference.frames.size():
  var row=reference.frames[index]
  if row.event!=null:model.trigger(row.event.intensity,Vector3(row.event.draws[0],row.event.draws[1],row.event.draws[2]))
  model.update([1.0/60,.05,.001,.1][index%4],index*.016)
  var actual=[model.time,model.power,model.value,model.direction.x,model.direction.y,model.direction.z];var expected=[row.time,row.power,row.value,row.direction[0],row.direction[1],row.direction[2]]
  for key in actual.size():
   var error=absf(actual[key]-expected[key]);maximum=maxf(maximum,error)
   if error>1e-6:failures.append("%d %d"%[index,key])
 var report={"frames":reference.frames.size(),"comparisons":reference.frames.size()*6,"failures":failures,"maximum_error":maximum,"scope":"Original actual render thunder callback plus flash expression; controlled Math.random draws, retrigger, zero/default/negative/clamped intensity, direction normalization and .9s decay boundary. Full post thunder not included."}
 var file=FileAccess.open("res://evidence/sky-weather-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"frames":report.frames,"failures":failures.size(),"first":failures.slice(0,10),"maximum_error":maximum}));quit(0 if failures.is_empty() else 1)
