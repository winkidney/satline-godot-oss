extends SceneTree
var failures=[]
var maximum=0.0
var checks=0
func compare(actual:Transform3D,expected:Transform3D,label:String)->void:
 var values=[actual.origin.distance_to(expected.origin),(actual.basis.x-expected.basis.x).length(),(actual.basis.y-expected.basis.y).length(),(actual.basis.z-expected.basis.z).length()]
 for error in values:
  maximum=maxf(maximum,error);checks+=1
  if (not is_finite(error) or error>2e-6) and failures.size()<20:failures.append(label+" error="+str(error))
func make_scene(source:Dictionary,animation_data:Dictionary):
 var scene=load("res://scripts/source_scene.gd").new();scene.source=source
 for record in source.nodes:scene.records[record.id]=record
 for id in animation_data.node_ids:
  var node=Node3D.new();node.name=scene.records[id].name if scene.records[id].name!="" else id;scene.source_nodes[id]=node
 for id in animation_data.node_ids:
  var parent=scene.records[id].parent
  if scene.source_nodes.has(parent):scene.source_nodes[parent].add_child(scene.source_nodes[id])
  else:scene.add_child(scene.source_nodes[id])
 for group_index in [2,39]:
  var group_id=animation_data.node_ids[group_index];var bones=[]
  for id in animation_data.node_ids:
   if scene.records[id].type!="Bone":continue
   var ancestor=scene.records[id].parent
   while ancestor!=null and ancestor!=group_id:ancestor=scene.records[ancestor].parent
   if ancestor==group_id:bones.append(id)
  var skeleton=Skeleton3D.new();scene.source_nodes[group_id].add_child(skeleton)
  for id in bones:skeleton.add_bone(id)
  for index in bones.size():skeleton.set_bone_parent(index,bones.find(scene.records[bones[index]].parent))
  scene.skin_bindings.append({"skeleton":skeleton,"bones":bones})
 return scene
func _initialize()->void:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/animations/weapon.json"))
 var base_scene=make_scene(source,data);var live_scene=make_scene(source,data);var Animation=load("res://scripts/weapon_animation.gd");var base=Animation.new(base_scene);var live=Animation.new(live_scene)
 var weapon=load("res://scripts/weapon.gd").new(source.modules.weapon);weapon.time=.1;base.last_shot=0;live.last_shot=0
 var sentinel=Transform3D(Basis.from_euler(Vector3(.2,.1,.3)),Vector3(6,7,8))
 for index in [0,1]:live_scene.source_nodes[data.node_ids[index]].transform=sentinel
 var cases=0;var repeats=0
 for gun in ["rifle","pistol"]:
  weapon.current=gun
  for mode in range(11):
   weapon.reload={} if mode<6 or mode>=8 else {"empty":mode==7,"t":1.48}
   weapon.time=.8 if mode>=8 else .1
   weapon.ads=[0.0,.5,1.0][mode%3];weapon.sprint_blend=0.0 if mode<3 or mode in [8,9] else .7
   weapon.holster=0; base.update(weapon)
   var active_id=weapon.rigs[gun].root["$node"];var inactive_id=weapon.rigs["pistol" if gun=="rifle" else "rifle"].root["$node"]
   var sampled=base_scene.source_nodes[active_id].transform;var inactive=live_scene.source_nodes[inactive_id].transform
   var target=Transform3D(Basis.from_euler(Vector3(.08,-.12,.04)),Vector3(.12,-.21,-.32))
   var delta=target*sampled.affine_inverse();weapon.holster=.9
   for repeat in 3:
    var commits=live.root_commits;live.update(weapon,target);repeats+=1
    if live.root_commits!=commits+1:failures.append("root commits")
    compare(live_scene.source_nodes[active_id].transform,target,"sole live root")
    compare(live_scene.source_nodes[inactive_id].transform,inactive,"inactive root retained")
    for index in [0,1]:compare(live_scene.source_nodes[data.node_ids[index]].transform,sentinel,"key/target untouched")
    for id in live.arm_group_ids:compare(live_scene.source_nodes[id].transform,delta*base_scene.source_nodes[id].transform,"arm delta nonaccumulation")
    for id in live.gun_child_ids:compare(live_scene.source_nodes[id].transform,base_scene.source_nodes[id].transform,"action child")
    for binding in live_scene.skin_bindings:
     for index in binding.bones.size():
      var id=binding.bones[index];compare(live_scene.source_nodes[id].transform,base_scene.source_nodes[id].transform,"bone proxy")
      compare(binding.skeleton.get_bone_pose(index),base_scene.source_nodes[id].transform,"bone Skeleton3D")
   var frozen_commits=live.root_commits;live.update(weapon)
   if live.root_commits!=frozen_commits:failures.append("freeze commits root")
   compare(live_scene.source_nodes[active_id].transform,target,"frozen root")
   cases+=1
 var retained=live_scene.source_nodes[weapon.rigs.rifle.root["$node"]].transform
 weapon.reset();live.update(weapon)
 compare(live_scene.source_nodes[weapon.rigs.rifle.root["$node"]].transform,retained,"session reset never restores sampled root")
 var report={"cases":cases,"repeated_live_updates":repeats,"checks":checks,"maximum_transform_error":maximum,"failures":failures,"scope":"Real animation code on exported104-node hierarchy and70 Skeleton3D bone slots; source clip baseline vs live root, one rigid arm-group delta, no accumulated transform, key/target/inactive root retained, no extra holster, frozen/reset writer guard. Synthetic live target, no original IK or GPU skin-image proof."}
 FileAccess.open("res://evidence/weapon-live-animation-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));base_scene.free();live_scene.free();quit(0 if failures.is_empty() else 1)
