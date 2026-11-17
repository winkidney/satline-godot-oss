extends RefCounted
var scene:SaltlineSourceScene
var motion
var roles:Dictionary={}
var owned:Dictionary={}
var rest:Dictionary={}
var magazine_motion
func _init(source:SaltlineSourceScene,controller,magazine=null)->void:
 scene=source;motion=controller;magazine_motion=magazine
 # Pinned original wS/zS assembly child order, bundle76790 /78469.
 var rifle=children(scene.source.modules.weapon.rigs.rifle.root["$node"])
 var pistol=children(scene.source.modules.weapon.rigs.pistol.root["$node"])
 roles={"rifle_bolt":rifle[4],"rifle_round":children(rifle[5])[1],"pistol_barrel":pistol[3],"pistol_slide":pistol[4],"pistol_stop":pistol[5],"pistol_round":children(pistol[6])[1]}
 if magazine_motion!=null:roles.merge({"rifle_magazine":rifle[5],"pistol_magazine":pistol[6]})
 for id in roles.values():owned[id]=true;rest[id]=scene.source_nodes[id].transform
 assert(scene.records[roles.pistol_barrel].type=="Group" and scene.records[roles.pistol_slide].type=="Group")
func children(id:String)->Array:
 var result=[]
 for record in scene.source.nodes:
  if record.parent==id:result.append(record.id)
 return result
func owns(id:String)->bool:return owned.has(id)
func apply()->void:
 for id in owned:scene.source_nodes[id].transform=rest[id]
 var rifle:Dictionary=motion.states.rifle;var pistol:Dictionary=motion.states.pistol
 scene.source_nodes[roles.rifle_bolt].position.z=rifle.slide
 scene.source_nodes[roles.rifle_round].visible=rifle.round_visible
 scene.source_nodes[roles.pistol_slide].position.z=pistol.slide
 scene.source_nodes[roles.pistol_barrel].rotation.x=pistol.barrel_pitch
 scene.source_nodes[roles.pistol_barrel].position.z=pistol.barrel_z
 scene.source_nodes[roles.pistol_stop].rotation.x=pistol.stop_pitch
 scene.source_nodes[roles.pistol_round].visible=pistol.round_visible
 if magazine_motion!=null:
  for gun in ["rifle","pistol"]:
   var node:Node3D=scene.source_nodes[roles[gun+"_magazine"]]
   node.transform=magazine_motion.poses[gun];node.visible=true
