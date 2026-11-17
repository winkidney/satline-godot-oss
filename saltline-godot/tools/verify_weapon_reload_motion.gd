extends SceneTree
const ReloadMotion=preload("res://scripts/weapon_reload_motion.gd")
var failures=[]
var comparisons=0
var maximum=0.0
var context=""
func fail(message:String)->void:
 if failures.size()<24:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  if actual.size()!=expected.size():fail(path+" dictionary size")
  for key in expected:
   if not actual.has(key):fail(path+" missing "+key)
   else:compare(actual[key],expected[key],path+"."+key)
 elif expected is Array:
  if actual.size()!=expected.size():fail(path+" array size");return
  for index in expected.size():compare(actual[index],expected[index],path+"/"+str(index))
 elif expected is bool or expected==null or expected is String:
  comparisons+=1
  if actual!=expected:fail(path+" value mismatch")
 else:
  comparisons+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if error>1e-12:fail(path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-reload-motion-reference.json"));var steps=0
 for gun in ["rifle","pistol"]:
  var native=ReloadMotion.RIFLE if gun=="rifle" else ReloadMotion.PISTOL
  for key in native:compare(native[key],reference.timings[gun][key],gun+".timings."+key)
 for sample in reference.cases:
  var state=sample.initial.duplicate(true);var motion=ReloadMotion.new(state)
  var reload={"t":0.0,"T":sample.duration,"empty":sample.empty,"f":{}}
  for index in sample.steps.size():
   context=sample.gun+"/"+str(sample.empty)+"/"+sample.mode+"/"+str(index)
   var row:Dictionary=sample.steps[index];reload.t=row.event_time
   motion.step(sample.gun,reload,row.time)
   compare(state,row.expected.state,"state");compare(reload.f,row.expected.flags,"flags");compare(motion.events,row.expected.events,"events");compare(motion.arm_impulses,row.expected.arm_impulses,"arm_impulses")
   steps+=1
  state.reloadW=.9;state.rackW=.7;state.antYT=.02;state.antRT=.03
  var preserved=state.kP.duplicate(true);motion.clear_targets()
  compare([state.reloadW,state.rackW,state.antYT,state.antRT],[0.0,0.0,0.0,0.0],"clear targets");compare(state.kP,preserved,"clear retains spring")
 var report={"cases":reference.cases.size(),"steps":steps,"comparisons":comparisons,"maximum_error":maximum,"tolerance":1e-12,"failures":failures,"source_sha256":reference.source_sha256,"state_segments_sha256":reference.state_segments_sha256,"scope":reference.scope+" Native root targets/impulses, once-only flags/events, arm impulse count. Ammo transfer remains weapon logic; no actual arm or part transforms tested."}
 FileAccess.open("res://evidence/weapon-reload-motion-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
