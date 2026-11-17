extends SceneTree
var events=[]
var failures=[]
var checks=0
var maximum=0.0
func encode_value(value:Variant)->Variant:
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Dictionary:
  var result={}
  for key in value:result[key]=encode_value(value[key])
  return result
 return value
func compare(a:Variant,b:Variant,label:String)->void:
 checks+=1
 if a is Dictionary:
  for key in b:compare(a.get(key),b[key],label+"/"+key)
 elif a is Array:
  if a.size()!=b.size():failures.append(label+" count");return
  for i in a.size():compare(a[i],b[i],label)
 elif a is int or a is float:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error)
  if error>0.000002:failures.append(label+" number")
 elif a!=b:failures.append(label+" value")
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/fx-showcase-reference.json"))
 for test in data.cases:
  var rng=preload("res://scripts/fx_random.gd").new(data.tape)
  var timeline=preload("res://scripts/fx_showcase_timeline.gd").new(test.mode,rng,func(kind,values):events.append([kind,encode_value(values)]),{"fxhold":test.hold,"fxsize":test.fixed})
  for row in test.rows:
   events.clear();timeline.update(.8 if int(row.frame)==25 else 0.0 if int(row.frame)==30 else 1.0/60);compare(events,row.events,test.mode+"/"+str(row.frame)+"/"+test.hold);compare(rng.calls,row.calls,"calls")
 var report={"cases":data.cases.size(),"checks":checks,"maximum_error":maximum,"failures":failures,"scope":"Literal KP C scheduling, callbacks recorded synchronously with no effect RNG/physics; 600 steps x10, modes/hold/fixed size, zero and large dt. Full scene integration pending."}
 FileAccess.open("res://evidence/fx-showcase-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
