extends SceneTree
class Presentation extends RefCounted:
 var roots={"rifle":true,"pistol":false}
 var wetness=1.0
 func sync_equip(weapon,previous)->void:roots[previous]=false;roots[weapon.current]=weapon.visible
 func sync_visibility(weapon)->void:roots[weapon.current]=weapon.visible
 func set_wetness(value)->void:wetness=value
var failures=[]
var checks=0
var maximum=0.0
func compare(a,b,context:String)->void:
 if b is Dictionary:
  if b.has("$number"):
   checks+=1
   if not is_inf(float(a)) or (float(a)>0)!=(b["$number"]=="Infinity"):failures.append(context)
  else:
   for key in b:compare(a[key],b[key],context+"/"+key)
 elif b is Array:
  for j in b.size():compare(a[j],b[j],context+"/"+str(j))
 elif b==null or b is bool or b is String:
  checks+=1
  if a!=b and failures.size()<20:failures.append({"context":context,"actual":a,"expected":b})
 else:
  checks+=1;var error=absf(float(a)-float(b));maximum=maxf(maximum,error)
  if (not is_finite(float(a)) or error>1e-12) and failures.size()<20:failures.append({"context":context,"actual":a,"expected":b,"error":error})
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-public-reference.json"))
 var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon,ref.initial,4207);var presenter=Presentation.new();weapon.bind_presentation(presenter)
 var steps=0
 for row in ref.rows:
  var input=row.input;weapon.motion_state.merge(input.patch.duplicate(true),true)
  weapon.switching={"active":true} if input.switching else {}
  if input.cancel:weapon.slots[weapon.current].ammo=5;weapon.reload_now()
  var result=null
  match input.action:
   "equip":weapon.equip(input.gun)
   "visible":weapon.set_visible(input.value)
   "view":result=weapon.set_view(input.value)
   "snap":weapon.snap(input.player,input.input,input.debug_ads,input.debug_sprint)
   "ammo":weapon.add_ammo(input.value)
   "wet":weapon.set_wetness(input.value)
  var actual={"state":weapon.motion_state,"current":weapon.current,"visible":weapon.visible,"ads":weapon.ads,"view":weapon.view,"rig_views":{"rifle":weapon.rigs.rifle.view,"pistol":weapon.rigs.pistol.view},"roots":presenter.roots,"reserves":{"rifle":weapon.slots.rifle.reserve,"pistol":weapon.slots.pistol.reserve},"engagement":weapon.arms.targeter.engagement,"groups":weapon.arms.blend.group_visible,"wetness":presenter.wetness,"result":result}
  compare(actual,row.expected,str(steps))
  for gun in weapon.rigs:
   if weapon.rigs[gun].pose!=weapon.rigs[gun].views[weapon.rigs[gun].view]:failures.append("view did not select pose")
  steps+=1
 weapon.equip("pistol");weapon.set_visible(false)
 var before=weapon.shot_count
 var player={"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
 for j in 30:weapon.update(1.0/60,{"fire":true,"ads":false},player)
 checks+=1
 if weapon.shot_count!=before or weapon.previous_fire:failures.append("hidden weapon fired or retained trigger edge")
 weapon.set_visible(true);weapon.update(1.0/60,{"fire":true,"ads":false},player)
 checks+=1
 if weapon.shot_count!=before+1:failures.append("show did not restore trigger edge")
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":1e-12,"failures":failures,"source_sha256":ref.source_sha256,"methods_sha256":ref.methods_sha256,"scope":ref.scope+" Actual Weapon API, weak presentation receiver, private motion and arm participation. No actual GPU nodes in this verifier."}
 FileAccess.open("res://evidence/weapon-public-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
