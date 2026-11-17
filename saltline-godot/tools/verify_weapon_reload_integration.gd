extends SceneTree
const Weapon=preload("res://scripts/weapon.gd")
const FIELDS=["bump","kZ","kP","kR","antYT","antRT","reloadW","rackW"]
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
func slot(weapon)->Dictionary:
 var value=weapon.slots[weapon.current]
 return {"ammo":value.ammo,"reserve":value.reserve,"magSize":value.mag_size}
func compare_step(weapon,active,trace,expected)->void:
 for key in FIELDS:compare(weapon.motion_state[key],expected.state[key],"S."+key)
 compare(weapon.reload_motion.events,expected.events,"events");compare(trace,expected.traces,"emit order")
 compare(slot(weapon),expected.slot,"slot");compare(active.seated,expected.seated,"seated");compare(weapon.reload_motion.arm_impulses,expected.arm_impulses,"arm impulses")
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-reload-motion-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var input={"fire":false,"ads":false};var player={"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false};var steps=0
 for sample in reference.cases:
  var weapon=Weapon.new(data.modules.weapon);weapon.current=sample.gun;weapon.slots[sample.gun].ammo=0 if sample.empty else 6;weapon.slots[sample.gun].reserve=100
  weapon.motion_state.clear();weapon.motion_state.merge(sample.initial.duplicate(true),true)
  context=sample.gun+"/"+str(sample.empty)+"/"+sample.mode
  if not weapon.reload_now():fail("start rejected")
  var active=weapon.reload;var traces=[];var done=[0]
  active.f._alias_probe=1
  if not active.events.has("_alias_probe"):fail("flags are not shared")
  active.f.erase("_alias_probe")
  var weapon_ref=weakref(weapon)
  weapon.phase_event.connect(func(event,gun,phase):
   if event!="reload":return
   if phase=="done":done[0]+=1;return
   if phase=="start":return
   var active_weapon=weapon_ref.get_ref();var state=active_weapon.motion_state;var s=active_weapon.slots[gun]
   traces.append({"phase":phase,"ammo":s.ammo,"reserve":s.reserve,"bump":state.bump.v,"kZ":state.kZ.v,"kP":state.kP.v,"kR":state.kR.v})
  )
  for index in sample.steps.size():
   var row=sample.steps[index]
   if row.time>=sample.duration:break
   context=sample.gun+"/"+str(sample.empty)+"/"+sample.mode+"/"+str(index)
   active.t=row.event_time;weapon.update(0,input,player)
   if weapon.reload.is_empty():fail("ended before T");break
   compare_step(weapon,active,traces,row.expected);compare(active.f,row.expected.flags,"flags");steps+=1
  active.t=sample.duration;weapon.update(0,input,player)
  compare_step(weapon,active,traces,sample.production_final)
  if not weapon.reload.is_empty() or weapon.motion_state.reload!=null or done[0]!=1:fail("done exactly once and clears context")
  weapon.update(0,input,player)
  if done[0]!=1:fail("done repeated")
 # Switch cancellation at either side of magin must not grant duplicate rounds.
 for at in [.5,1.5]:
  var weapon=Weapon.new(data.modules.weapon);weapon.slots.rifle.ammo=6;weapon.slots.rifle.reserve=100;weapon.reload_now();weapon.update(0,input,player);weapon.update(at,input,player)
  var before=slot(weapon);weapon.switch_to("pistol");weapon.update(0,input,player)
  compare(weapon.slots.rifle.ammo,before.ammo,"cancel ammo");compare(weapon.slots.rifle.reserve,before.reserve,"cancel reserve")
  compare([weapon.motion_state.reloadW,weapon.motion_state.rackW,weapon.motion_state.antYT,weapon.motion_state.antRT],[0,0,0,0],"cancel targets")
  if weapon.motion_state.reload!=null:fail("cancel keeps context")
  weapon.reset()
  if weapon.motion_state.reload!=null or not weapon.reload_motion.events.is_empty():fail("reset context and diagnostics")
 # Fresh is a timing flag, independent of f.fresh magazine replacement.
 var fresh_weapon=Weapon.new(data.modules.weapon);fresh_weapon.slots.rifle.ammo=6
 var fresh_input={"fire":false,"ads":false,"reload":true}
 fresh_weapon.update(.5,fresh_input,player)
 compare(fresh_weapon.reload.t,0.0,"fresh first update")
 if fresh_weapon.reload.f.has("fresh"):fail("timing fresh leaked into magazine fresh")
 fresh_weapon.update(.2,input,player);compare(fresh_weapon.reload.t,.2,"fresh second update")
 # A phase callback may cancel the active reload; the current method retains its context.
 var reentrant=Weapon.new(data.modules.weapon);reentrant.slots.rifle.ammo=6;reentrant.reload_now()
 var reentrant_ref=weakref(reentrant)
 reentrant.phase_event.connect(func(event,_gun,phase):
  if event=="reload" and phase=="magout":reentrant_ref.get_ref().switch_to("pistol")
 )
 reentrant.update(0,input,player);reentrant.update(.5,input,player)
 if not reentrant.reload.is_empty() or reentrant.pending!="pistol":fail("phase cancellation")
 compare(reentrant.slots.rifle.ammo,6,"phase cancel ammo")
 reentrant.update(0,input,player)
 compare([reentrant.motion_state.reloadW,reentrant.motion_state.rackW,reentrant.motion_state.antYT,reentrant.motion_state.antRT],[0,0,0,0],"phase cancel next tick targets")
 # A retained kernel must not keep its owner alive or apply a stale event impulse.
 var owner=Weapon.new(data.modules.weapon);var owner_ref=weakref(owner);var retained=owner.reload_motion
 owner=null
 if owner_ref.get_ref()!=null:fail("kernel retains owner")
 var stale={"t":.5,"T":2.24,"empty":false,"f":{}}
 var before_bump=retained.a.bump.v;retained.step("rifle",stale,.5)
 compare(retained.a.bump.v,before_bump,"dead owner impulse")
 if not stale.f.is_empty() or not retained.events.is_empty():fail("dead owner events")
 var report={"cases":reference.cases.size(),"active_steps":steps,"comparisons":comparisons,"maximum_error":maximum,"failures":failures,"tolerance":1e-12,"scope":"Production SaltlineWeapon.update with actual delegated reload event owner, original literal f/h plus reload state-segment reference. Per-step source event/slot/velocity-before-impulse traces, completion and cancellation. Explicit synthetic reload.t sampling, dt0; no D/root transform/IK or OS input proof."}
 FileAccess.open("res://evidence/weapon-reload-integration-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
