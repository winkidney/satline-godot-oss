extends SceneTree
var failures=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 var source=load("res://scripts/source_scene.gd").new()
 source.source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 for record in source.source.nodes:source.records[record.id]=record
 var animation=load("res://scripts/weapon_animation.gd").new(source)
 for id in animation.data.node_ids:source.source_nodes[id]=Node3D.new()
 var weapon=load("res://scripts/weapon.gd").new(source.source.modules.weapon)
 var checks=0;var maximum_error=0.0;var mechanical_displacement={}
 for gun in ["rifle","pistol"]:
  weapon.current=gun
  var moving_index=81 if gun=="rifle" else 94
  mechanical_displacement[gun]=animation._sample(gun+"_fire",0.0,moving_index).origin.z-animation._sample(gun+"_ads",0.0,moving_index).origin.z
  for mode in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2(.5,.5)]:
   weapon.ads=mode.x;weapon.sprint_blend=mode.y
   for frame in 30:
    weapon.time=float(frame)/60.0;animation.last_shot=0.0
    animation.update(weapon)
    for index in animation.data.node_ids.size():
     var id=animation.data.node_ids[index]
     if not animation.gun_child_ids.has(id):continue
     var expected=animation.data.clips[gun+"_fire"].frames[frame][index]
     var node=source.source_nodes[id]
     var error=node.position.distance_to(Vector3(expected[0],expected[1],expected[2]))
     var q=Quaternion(expected[3],expected[4],expected[5],expected[6]).normalized()
     error=maxf(error,1.0-absf(node.quaternion.dot(q)))
     maximum_error=maxf(maximum_error,error);checks+=1
     if error>1e-6 and failures.size()<20:failures.append({"gun":gun,"mode":str(mode),"frame":frame,"id":id,"error":error})
 for gun in mechanical_displacement:
  if mechanical_displacement[gun]<.02:failures.append("Missing original fire displacement: "+gun)
 var report={"checks":checks,"maximum_transform_error":maximum_error,"source_fire_minus_ads_z":mechanical_displacement,"gun_child_nodes":animation.gun_child_ids.size(),"failures":failures,"scope":"Original exported fire frames for both guns, all mechanical descendants, ADS/sprint 0/1/mixed; local position and quaternion. Lightweight actual animation execution; no rendered image, root dynamics or IK proof."}
 FileAccess.open("res://evidence/weapon-mechanics-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report))
 for node in source.source_nodes.values():node.free()
 source.free();quit(0 if failures.is_empty() else 1)
