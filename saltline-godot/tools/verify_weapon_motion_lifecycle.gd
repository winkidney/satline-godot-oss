extends SceneTree
const Lifecycle=preload("res://scripts/weapon_motion_lifecycle.gd")
var failures=[]
var comparisons=0
var maximum=0.0
var context=""
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  if actual.size()!=expected.size() and failures.size()<20:failures.append(context+" "+path+" dictionary size")
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is bool or expected==null:
  comparisons+=1
  if actual!=expected and failures.size()<20:failures.append(context+" "+path+" mismatch")
 else:
  comparisons+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):
   if failures.size()<20:failures.append(context+" "+path+" non-finite")
   return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if error>1e-12 and failures.size()<20:failures.append(context+" "+path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-motion-lifecycle-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 if reference==null:push_error("Missing lifecycle fixture");quit(1);return
 var state=reference.initial.duplicate(true);var lifecycle=Lifecycle.new(state,data.modules.weapon.rigs)
 for index in reference.steps.size():
  var row:Dictionary=reference.steps[index].input;context=str(index)+"/"+row.action
  state.merge(row.patch.duplicate(true),true)
  if row.action=="equip":lifecycle.equip(row.gun)
  elif row.action=="reset":lifecycle.reset()
  else:lifecycle.snap(row.player,row.input,row.switching,row.debug_ads,row.debug_sprint)
  compare(state,reference.steps[index].expected,"state")
 var report={"coverage":reference.coverage,"operations":reference.steps.size(),"comparisons":comparisons,"maximum_error":maximum,"tolerance":1e-12,"failures":failures,"source_sha256":reference.source_sha256,"lifecycle_sha256":reference.lifecycle_sha256,"scope":reference.scope}
 FileAccess.open("res://evidence/weapon-motion-lifecycle-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
