extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
var maximum_view=0.0
var context=""
func fail(message:String)->void:
 if failures.size()<20:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is bool:
  checks+=1
  if actual!=expected:fail(path+" bool")
 else:
  checks+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if error>1e-12:fail(path+" error="+str(error))
func view_value(actual:float,expected:float,label:String)->void:
 checks+=1;var error=absf(actual-expected);maximum_view=maxf(maximum_view,error)
 if not is_finite(actual) or error>2e-6:fail(label+" view error="+str(error))
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var animation_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/animations/weapon.json"));var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-parts-reference.json"));var operations=0
 for sample in reference.cases:
  var parts=load("res://scripts/weapon_parts_motion.gd").new();var state=data.modules.weapon.debug.S.duplicate(true);var reload_motion=load("res://scripts/weapon_reload_motion.gd").new(state);reload_motion.parts_motion=parts
  var scene=load("res://scripts/source_scene.gd").new();scene.source=data
  for record in data.nodes:scene.records[record.id]=record
  for id in animation_data.node_ids:
   var node=Node3D.new();node.transform=scene._transform(scene.records[id].matrix);scene.source_nodes[id]=node;scene.add_child(node)
  var view=load("res://scripts/weapon_parts_view.gd").new(scene,parts);var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon);weapon.current=sample.gun;weapon.time=.1;weapon.ads=1;weapon.sprint_blend=1
  var animation=load("res://scripts/weapon_animation.gd").new(scene);animation.parts_view=view;animation.last_shot=0
  var role_indices={"rifle_bolt":81,"rifle_round":84,"pistol_barrel":92,"pistol_slide":94,"pistol_stop":98,"pistol_round":101}
  for role in role_indices:
   if view.roles[role]!=animation_data.node_ids[role_indices[role]]:fail("pinned source role "+role)
  var active={}
  for index in sample.rows.size():
   context=sample.gun+"/"+str(index);var row=sample.rows[index].input
   match row.action:
    "reset":parts.reset(sample.gun)
    "shot":parts.shot(sample.gun,row.empty)
    "lock":parts.set_locked(sample.gun,row.value)
    "start":active={"t":0.0,"T":(2.72 if row.empty else 2.24) if sample.gun=="rifle" else (1.9 if row.empty else 1.5),"empty":row.empty,"f":{}}
    "reload":active.t=row.time;reload_motion.step(sample.gun,active,row.time)
    "cancel":parts.cancel_reload(sample.gun,row.seated,row.ammo)
    "end":parts.end_reload(sample.gun)
    "step":parts.step(sample.gun,row.dt,row.finger,row.reloading)
   compare(parts.states[sample.gun],sample.rows[index].expected,"private state")
   animation.update(weapon,Transform3D.IDENTITY)
   var rifle=parts.states.rifle;var pistol=parts.states.pistol
   view_value(scene.source_nodes[view.roles.rifle_bolt].position.z,rifle.slide,"rifle bolt")
   view_value(scene.source_nodes[view.roles.pistol_slide].position.z,pistol.slide,"pistol slide")
   view_value(scene.source_nodes[view.roles.pistol_barrel].position.z,pistol.barrel_z,"barrel z")
   view_value(scene.source_nodes[view.roles.pistol_barrel].rotation.x,pistol.barrel_pitch,"barrel pitch")
   view_value(scene.source_nodes[view.roles.pistol_stop].rotation.x,pistol.stop_pitch,"slide stop")
   if scene.source_nodes[view.roles.rifle_round].visible!=rifle.round_visible or scene.source_nodes[view.roles.pistol_round].visible!=pistol.round_visible:fail("round visibility sampled over live state")
   operations+=1
  scene.free()
 var report={"operations":operations,"checks":checks,"maximum_state_error":maximum,"maximum_view_error":maximum_view,"failures":failures,"source_sha256":reference.source_sha256,"parts_sha256":reference.parts_sha256,"scope":reference.scope+" Actual animation+parts renderer with pinned original role nodes under ADS/sprint sampling pressure. Scalar1e-12/view2e-6. Magazine trajectory is covered by separate magazine verifiers; hand targets remain sampled; no complete IK or source whole-world proof."}
 FileAccess.open("res://evidence/weapon-parts-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
