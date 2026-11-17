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
var queries=[]
func query(origin:Vector3,direction:Vector3,distance:float)->Dictionary:
 queries.append({"origin":encode_value(origin),"direction":encode_value(direction),"range":distance})
 if queries.size()%5==0:return {}
 return {"point":origin+direction*3,"normal":Vector3.UP,"surface":"metal"}
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/fx-showcase-impact-reference.json"))
 var rng=preload("res://scripts/fx_random.gd").new(data.tape)
 var target=preload("res://scripts/fx_showcase_impact.gd").new(rng,query,func(kind,values):events.append([kind,encode_value(values)]))
 for row in data.rows:
  events.clear();var previous=queries.size();target.trigger(int(row.index))
  compare(events,row.events,"events")
  compare(rng.calls,row.calls,"calls")
  if row.query!=null:compare(queries.back(),row.query,"raycast")
  elif queries.size()!=previous:failures.append("unexpected raycast")
 var report={"steps":data.rows.size(),"checks":checks,"maximum_error":maximum,"failures":failures,"scope":"Literal KP I vs native target selection, alternating origins, eight kinds, raycast misses, water/dirt overrides, enemy bypass; mock raycast at distance3, no actual physics/render."}
 FileAccess.open("res://evidence/fx-showcase-impact-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
