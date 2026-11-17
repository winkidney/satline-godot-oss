class_name SaltlineRelays
extends RefCounted

var scene:SaltlineSourceScene
var items:Dictionary={}
func _init(source:SaltlineSourceScene)->void:
 scene=source
 var objectives:Array=scene.source.modules.level.objectives
 for index in objectives.size():
  var objective:Dictionary=objectives[index];var root:Dictionary=scene.records[objective.object["$node"]]
  var material_id:String=root.userData.emissiveMaterial["$material"];var parent_id=""
  for node in scene.source.nodes:
   if material_id in node.get("materials",[]):parent_id=node.parent;break
  assert(not parent_id.is_empty(),"Relay dynamic mesh missing")
  var doors=[];var spinners=[]
  for node in scene.source.nodes:
   if node.parent!=parent_id or material_id in node.get("materials",[]):continue
   var position=Vector3(node.matrix[12],node.matrix[13],node.matrix[14])
   if position.y<.01:doors.append(scene.source_nodes[node.id])
   else:spinners.append(scene.source_nodes[node.id])
  items[objective.id]={"animation":SaltlineRelayAnimation.new(index+1,scene.source.time.t),"material":scene.materials[material_id],"doors":doors,"spinners":spinners}

func set_state(relay:Dictionary,value:String)->void:
 if items.has(relay.id):items[relay.id].animation.set_state(value)

func update(dt:float)->void:
 for item in items.values():
  var animation:SaltlineRelayAnimation=item.animation;animation.update(dt)
  var color=Color.hex((animation.color_hex<<8)|255).srgb_to_linear()
  item.material.set_shader_parameter("base_color",Vector3(color.r,color.g,color.b)*animation.level)
  for node in item.spinners:node.rotate_object_local(Vector3.UP,animation.spin_delta)
  for node in item.doors:node.rotate_object_local(Vector3.UP,-animation.hinge_delta)
