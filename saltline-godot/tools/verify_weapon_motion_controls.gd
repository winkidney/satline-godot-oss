extends SceneTree
const Controls=preload("res://scripts/weapon_motion_controls.gd")
var failures=[]
var maximum=0.0
var comparisons=0
var context=""
func fail(message:String)->void:
 if failures.size()<20:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is Array:
  if actual.size()!=expected.size():fail(path+" array size");return
  for i in expected.size():compare(actual[i],expected[i],path+"/"+str(i))
 elif expected is bool or expected==null or expected is String:
  comparisons+=1
  if actual!=expected:fail(path+" mismatch")
 else:
  comparisons+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if error>1e-12:fail(path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-motion-controls-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var steps=0
 if reference==null:push_error("Missing controls fixture");quit(1);return
 for sample in reference.cases:
  var state=sample.initial.duplicate(true);var controls=Controls.new(state)
  for index in sample.steps.size():
   context=sample.gun+"/"+str(index);var row=sample.steps[index].input
   state.merge(row.patch.duplicate(true),true);controls.targets(row.sprint,row.fire,row.input.ads,state.reload!=null)
   if row.dry:controls.dry()
   var inspect=controls.finish(row.dt,data.modules.weapon.rigs[sample.gun].def,row.input,row.speed,row.switching,row.fire,row.can_fire)
   compare(state,sample.steps[index].expected.state,"S");compare(inspect,sample.steps[index].expected.inspect,"inspect");steps+=1
 var production_steps=0
 for sample in reference.production_cases:
  var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon,sample.initial,4207);weapon.current=sample.gun;weapon.time=sample.initial.t
  weapon.slots[sample.gun].ammo=0;weapon.slots[sample.gun].reserve=0
  var dry=[];var weapon_ref=weakref(weapon)
  weapon.phase_event.connect(func(event,gun,_phase):
   if event=="dry":dry.append({"time":weapon_ref.get_ref().time,"weapon":gun})
  )
  for index in sample.steps.size():
   context="production/"+sample.gun+"/"+str(index);var row=sample.steps[index].input
   weapon.update(row.dt,row.input,row.player)
   var state=weapon.motion_state
   var actual={"t":weapon.time,"adsWant":state.adsWant,"spWant":state.spWant,"urgent":state.urgent,"idleT":state.idleT,"inspect":state.inspect,"finger":state.finger,"bump":state.bump.v,"adsE":weapon.ads,"adsLin":weapon.ads_linear,"sprintT":weapon.sprint_blend,"spreadS":weapon.spread,"cooldown":weapon.cooldown,"previous_fire":weapon.previous_fire,"state":weapon.state,"windows":weapon.motion_inspect,"dry":dry}
   compare(actual,sample.steps[index].expected,"O controls");production_steps+=1
  if weapon.shot_count!=0:fail("empty gun fired")
 var report={"coverage":reference.coverage,"cases":reference.cases.size(),"steps":steps,"production_steps":production_steps,"original_O_sha256":reference.original_O_sha256,"comparisons":comparisons,"maximum_error":maximum,"tolerance":1e-12,"failures":failures,"source_sha256":reference.source_sha256,"segments_sha256":reference.segments_sha256,"scope":reference.scope}
 FileAccess.open("res://evidence/weapon-motion-controls-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
