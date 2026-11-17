extends SceneTree
class Avatar extends RefCounted:
 var crouching=false
 var camera=[]
 var shake=[]
 func add_recoil(pitch:float,yaw:float)->void:camera.append([pitch,yaw])
 func add_shake(value:float)->void:shake.append(value)
var failures=[]
var maximum=0.0
var comparisons=0
var context=""
func fail(message:String)->void:
 if failures.size()<20:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if actual is Vector3:actual=[actual.x,actual.y,actual.z]
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is Array:
  if actual.size()!=expected.size():fail(path+" size");return
  for i in expected.size():compare(actual[i],expected[i],path+"/"+str(i))
 else:
  comparisons+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  var channel=path.trim_prefix(".")
  var tolerance=2e-6 if channel.begins_with("direction") or channel.begins_with("shell") or channel.begins_with("flash.scale") else 1e-11
  if error>tolerance:fail(path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-shot-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 for sample in reference.cases:
  var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon) if sample.canonical else load("res://scripts/weapon.gd").new(data.modules.weapon,sample.initial,int(sample.seed));weapon.current=sample.gun;weapon.time=sample.initial.t;weapon.slots[sample.gun].ammo=1000
  var avatar=Avatar.new();var effects=load("res://scripts/weapon_effects.gd").new();effects.weapon=weapon;effects.flashes[sample.gun]={}
  var rows=[{}];var actual=[{}]
  weapon.fired.connect(func(_gun,definition,spread):
   var direction=weapon.sample_spread(spread);var shell=weapon.sample_shell_velocity();weapon.apply_recoil(avatar);effects.fire(sample.gun,definition,false)
   var impulses={}
   for key in ["kZ","kP","kY","kR","kX","kU"]:impulses[key]=weapon.motion_state[key].v
   var flash=effects.flashes[sample.gun]
   actual[0]={"bloom":weapon.bloom,"direction":direction,"shell":shell,"camera":avatar.camera.duplicate(true),"shake":avatar.shake.duplicate(),"random_calls":weapon.root_motion.random_calls,"burst":weapon.burst,"root":impulses,"flash":{"duration":flash.duration,"seed":flash.seed,"jet":flash.jet,"roll":flash.roll,"scale":flash.scale}}
  )
  for index in sample.steps.size():
   context=sample.gun+"/"+str(index);var row=sample.steps[index].input;weapon.time+=row.dt;weapon.ads=row.ads;weapon.motion_state.adsE=row.ads;weapon.spread=row.spread;avatar.crouching=row.crouching;avatar.camera.clear();avatar.shake.clear();weapon._shoot()
   var expected=sample.steps[index].expected.duplicate(true);expected.erase("order")
   compare(actual[0],expected,"")
  var idle_player={"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
  for expected_quiet in sample.quiet:
   weapon.update(.3,{"fire":false,"ads":false},idle_player)
   compare({"recPhase":weapon.motion_state.recPhase,"burst":weapon.burst,"random_calls":weapon.root_motion.random_calls},expected_quiet,"quiet")
  weapon.fired.disconnect(weapon.fired.get_connections()[0].callable)
  effects.free()
 var report={"shots":reference.cases.size()*24,"comparisons":comparisons,"maximum_error":maximum,"failures":failures,"Q_sha256":reference.Q_sha256,"scope":reference.scope}
 FileAccess.open("res://evidence/weapon-shot-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
