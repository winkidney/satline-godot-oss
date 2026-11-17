class_name SaltlineWeaponAnimation
extends RefCounted

var scene:SaltlineSourceScene
var data:Dictionary
var bone_targets:Dictionary={}
var last_shot=-9.0
var gun_child_ids:Dictionary={}
var root_indices:Dictionary={}
var arm_node_ids:Dictionary={}
var arm_group_ids:Array=[]
var live_root_enabled=false
var root_commits=0
var last_sampled_root=Transform3D.IDENTITY
var last_arm_delta=Transform3D.IDENTITY
var parts_view
var drop_view

func _init(source_scene:SaltlineSourceScene)->void:
 scene=source_scene
 data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/animations/weapon.json"))
 # Mechanical children animate independently of the camera-local gun pose.
 var roots:Dictionary={}
 for rig in scene.source.modules.weapon.rigs.values():roots[rig.root["$node"]]=true
 for index in data.node_ids.size():
  var id=data.node_ids[index]
  if roots.has(id):root_indices[id]=index
  var ancestor=id
  while ancestor!=null and scene.records.has(ancestor):
   if scene.records[ancestor].type=="Group" and scene.records[ancestor].name in ["arm-left","arm-right"]:
    arm_node_ids[id]=true
    if not arm_group_ids.has(ancestor):arm_group_ids.append(ancestor)
    break
   ancestor=scene.records[ancestor].parent
  var parent=scene.records[id].parent
  while parent!=null and scene.records.has(parent):
   if roots.has(parent):
    gun_child_ids[id]=true
    break
   parent=scene.records[parent].parent
 for binding in scene.skin_bindings:
  for i in binding.bones.size():
   var id:String=binding.bones[i]
   if not bone_targets.has(id):bone_targets[id]=[]
   if not bone_targets[id].any(func(item):return item[0]==binding.skeleton and item[1]==i):bone_targets[id].append([binding.skeleton,i])

func _sample(name:String,time:float,index:int)->Transform3D:
 var clip:Dictionary=data.clips[name]
 var cursor=clampf(time*clip.fps,0,clip.frames.size()-1)
 var frame=int(floor(cursor));var next=mini(frame+1,clip.frames.size()-1)
 var a:Array=clip.frames[frame][index];var b:Array=clip.frames[next][index]
 var rotation=Quaternion(a[3],a[4],a[5],a[6]).normalized().slerp(Quaternion(b[3],b[4],b[5],b[6]).normalized(),cursor-frame)
 var position=Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),cursor-frame)
 var scale=Vector3(a[7],a[8],a[9]).lerp(Vector3(b[7],b[8],b[9]),cursor-frame)
 var basis=Basis(rotation);basis.x*=scale.x;basis.y*=scale.y;basis.z*=scale.z
 return Transform3D(basis,position)

func update(weapon:SaltlineWeapon,live_root:Variant=null)->void:
 if live_root!=null:live_root_enabled=true
 var base=weapon.current+"_hip"
 var cursor=fmod(weapon.time,1)
 if not weapon.reload.is_empty():
  base=weapon.current+("_reload_empty" if weapon.reload.empty else "_reload_tac");cursor=weapon.reload.t
 elif weapon.time-last_shot<.5:
  base=weapon.current+"_fire";cursor=weapon.time-last_shot
 var active_id:String=weapon.rigs[weapon.current].root["$node"]
 var sampled_root=Transform3D.IDENTITY
 for index in data.node_ids.size():
  var id:String=data.node_ids[index]
  if not scene.source_nodes.has(id):continue
  var pose=_sample(base,cursor,index)
  if weapon.reload.is_empty() and not gun_child_ids.has(id):
   if weapon.ads>0:pose=pose.interpolate_with(_sample(weapon.current+"_ads",cursor,index),weapon.ads)
   if weapon.sprint_blend>0:pose=pose.interpolate_with(_sample(weapon.current+"_sprint",cursor,index),weapon.sprint_blend)
  if id==active_id:sampled_root=pose
  if drop_view!=null and drop_view.motion.active and (gun_child_ids.has(id) or id==weapon.rigs[drop_view.motion.gun].root["$node"]):continue
  if weapon.arms.live and arm_node_ids.has(id):continue
  if parts_view!=null and parts_view.owns(id):continue
  if live_root_enabled and (root_indices.has(id) or (not gun_child_ids.has(id) and not arm_node_ids.has(id))):continue
  var node:Node3D=scene.source_nodes[id]
  node.transform=pose
  var clip:Dictionary=data.clips[base]
  node.visible=bool(clip.frames[mini(int(cursor*clip.fps),clip.frames.size()-1)][index][10])
  if bone_targets.has(id):
   for target in bone_targets[id]:target[0].set_bone_pose(target[1],pose)
 if parts_view!=null:parts_view.apply()
 if live_root_enabled:
  var root_node:Node3D=scene.source_nodes[active_id]
  var target:Transform3D=live_root if live_root!=null else root_node.transform
  last_sampled_root=sampled_root;last_arm_delta=target*sampled_root.affine_inverse()
  if not weapon.arms.live:
   for id in arm_group_ids:
    if scene.source_nodes.has(id):scene.source_nodes[id].transform=last_arm_delta*scene.source_nodes[id].transform
  if live_root!=null:root_node.transform=live_root;root_commits+=1
 if weapon.arms.live:_apply_live_arms(weapon.arms)
 # Legacy sampling remains available for isolated clip tests. Production D owns root.
 for gun in weapon.rigs:
  var root:Node3D=scene.source_nodes[weapon.rigs[gun].root["$node"]]
  root.visible=drop_view.motion.visible if drop_view!=null and drop_view.motion.active and gun==drop_view.motion.gun else gun==weapon.current and weapon.visible
  if root.visible and not live_root_enabled:
   root.position.y-=weapon.holster*.35
   root.rotate_x(weapon.holster*.35)
  var flash:Node3D=scene.source_nodes[weapon.rigs[gun].flash["$node"]]
  flash.visible=false # Native weapon effects apply visibility after animation sampling.

func _apply_live_arms(arms)->void:
 for id in arm_group_ids:
  scene.set_source_transform(id,Transform3D.IDENTITY)
  var side="l" if scene.records[id].name=="arm-left" else "r"
  scene.source_nodes[id].visible=arms.blend.group_visible[side]
 for id in arm_node_ids:
  var record=scene.records[id]
  if record.type!="Bone":continue
  var index=arms.bone_names.find(record.name)
  assert(index>=0,"Unknown source arm bone: "+str(record.name))
  var ancestor=id
  while scene.records[ancestor].name not in ["arm-left","arm-right"]:ancestor=scene.records[ancestor].parent
  var side="l" if scene.records[ancestor].name=="arm-left" else "r"
  var bone=arms.models[side].bones[index];var q=bone.q;var p=bone.p
  scene.set_source_transform(id,Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])),Vector3(p[0],p[1],p[2])))

func sync_equip(weapon,previous:String)->void:
 scene.source_nodes[weapon.rigs[previous].root["$node"]].visible=false
 scene.source_nodes[weapon.rigs[previous].flash["$node"]].visible=false
 if drop_view!=null and drop_view.motion.active and drop_view.motion.gun==previous:drop_view.motion.visible=false
 scene.source_nodes[weapon.rigs[weapon.current].root["$node"]].visible=weapon.visible
func sync_visibility(weapon)->void:
 scene.source_nodes[weapon.rigs[weapon.current].root["$node"]].visible=weapon.visible
 if drop_view!=null and drop_view.motion.active and drop_view.motion.gun==weapon.current:drop_view.motion.visible=weapon.visible
 for id in arm_group_ids:
  var side="l" if scene.records[id].name=="arm-left" else "r"
  scene.source_nodes[id].visible=weapon.arms.blend.group_visible[side]
func set_wetness(value:float)->void:
 scene.weapon_wetness=value
 for binding in scene.weapon_wet_materials:binding[0].set_shader_parameter(binding[1],value)
