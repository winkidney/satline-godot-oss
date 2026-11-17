extends "res://tools/verify_weapon_magazine_runtime.gd"
var bone_checks=0
var skeleton_checks=0
var arm_steps=0
func _process(dt:float)->bool:
 if game==null or finishing:return super._process(dt)
 var before=game.weapon.arms.steps
 var result=super._process(dt)
 var arms=game.weapon.arms
 if arms.steps!=before+1:fail("arm solve must run once per live game tick")
 arm_steps+=1
 for id in game.weapon_animation.arm_group_ids:
  if game.source_scene.source_nodes[id].transform!=Transform3D.IDENTITY:fail("live arms retain sampled group delta")
 for id in game.weapon_animation.arm_node_ids:
  var record=game.source_scene.records[id]
  if record.type!="Bone":continue
  var ancestor=id
  while game.source_scene.records[ancestor].name not in ["arm-left","arm-right"]:ancestor=game.source_scene.records[ancestor].parent
  var side="l" if game.source_scene.records[ancestor].name=="arm-left" else "r"
  var index=arms.bone_names.find(record.name);var bone=arms.models[side].bones[index];var q=bone.q;var p=bone.p
  var expected=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])),Vector3(p[0],p[1],p[2]))
  if not game.source_scene.source_nodes[id].transform.is_equal_approx(expected):fail("live proxy bone overwritten: "+record.name)
  bone_checks+=1
  for target in game.source_scene.bone_targets.get(id,[]):
   if not target[0].get_bone_pose(target[1]).is_equal_approx(expected):fail("live Skeleton3D bone overwritten: "+record.name)
   skeleton_checks+=1
 if frame in [110,350]:call_deferred("capture",frame)
 return result
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/arms-runtime-%03d.png"%requested)
func finish()->void:
 var report={"frames":frame,"steps":arm_steps,"proxy_bone_checks":bone_checks,"skeleton_bone_checks":skeleton_checks,"failures":failures,"scope":"Actual Main live vS/Fh normal pipeline writes all70 source proxy and Skeleton3D bones once per game tick; group identity/no sample overwrite. Separate literal source kernel proofs; no full source combined image/death-drop proof."}
 FileAccess.open("res://evidence/weapon-arms-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 await super.finish()
