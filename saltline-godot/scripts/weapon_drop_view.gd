extends RefCounted
var scene
var camera:Camera3D
var view_camera:Camera3D
var motion
var node:Node3D
var parent:Node
var saved=[]
var shaders=[]
var steps=0
func _init(source,world_camera:Camera3D,weapon_camera:Camera3D,random:Callable)->void:
 scene=source;camera=world_camera;view_camera=weapon_camera
 motion=preload("res://scripts/weapon_drop_motion.gd").new(random)
func array3(v:Vector3)->Array:return [v.x,v.y,v.z]
func array4(q:Quaternion)->Array:return [q.x,q.y,q.z,q.w]
func _materials(mesh:MeshInstance3D)->Array:
 var materials=[]
 if mesh.material_override!=null:return [mesh.material_override]
 for j in mesh.mesh.get_surface_count():materials.append(mesh.get_active_material(j))
 return materials
func _world_material(material:Material)->void:
 if not material is ShaderMaterial or material.shader==null:return
 if shaders.any(func(item):return item.material==material):return
 var shader:Shader=material.shader
 if not shader.code.contains("saltline_bias_weapon_3"):return
 var variant=Shader.new();variant.code=shader.code.replace("saltline_bias_weapon_3","saltline_bias_world_3")
 variant.set_meta("source_shader_path",shader.get_meta("source_shader_path",shader.resource_path));variant.set_meta("source_polygon_offset_mode","saltline_bias_world_3")
 shaders.append({"material":material,"shader":shader,"mode":material.get_meta("source_polygon_offset_mode","")})
 material.shader=variant;material.set_meta("source_polygon_offset_mode","saltline_bias_world_3")
func _visit(root:Node,flash:Node)->void:
 if root is GeometryInstance3D:
  saved.append({"node":root,"layers":root.layers,"shadow":root.cast_shadow})
  root.layers=1;root.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if root==flash else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
  if root is MeshInstance3D:
   for material in _materials(root):_world_material(material)
 for child in root.get_children():_visit(child,flash)
func start(weapon,player)->bool:
 if motion.active:return false
 node=scene.source_nodes[weapon.rigs[weapon.current].root["$node"]]
 if not node.visible:return false
 weapon.cancel_reload();weapon.switching={};weapon.pending=""
 var flash=scene.source_nodes[weapon.rigs[weapon.current].flash["$node"]];flash.visible=false
 parent=node.get_parent()
 motion.start(weapon.current,array3(node.position),array4(node.quaternion),array3(camera.global_position),array4(camera.global_basis.get_rotation_quaternion()),camera.fov,view_camera.fov,array3(player.velocity),weapon.arms.start_drop)
 node.reparent(scene,false);_visit(node,flash)
 apply();weapon.state="dropped"
 return true
func apply()->void:
 if not motion.active:return
 var q=motion.rotation;var p=motion.position
 node.global_transform=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])),Vector3(p[0],p[1],p[2]));node.visible=motion.visible
func advance(dt:float,weapon,player,effects)->void:
 if not motion.active and not start(weapon,player):return
 motion.splash=func(p,size):effects.splash(Vector3(p[0],p[1],p[2]),size)
 var ray=func(p,d,distance):
  var hit=player.physics.raycast(Vector3(p[0],p[1],p[2]),Vector3(d[0],d[1],d[2]),distance)
  return null if hit.is_empty() else hit
 var ground=func(x,z,y):return player.physics.ground_height(x,z,y)
 motion.step(dt,ray,ground,weapon.arms.drop_step);apply();steps+=1
func restore(weapon)->void:
 if not motion.active:return
 node.reparent(parent,false);node.scale=Vector3.ONE;node.visible=false
 for item in saved:
  item.node.layers=item.layers;item.node.cast_shadow=item.shadow
 for item in shaders:
  item.material.shader=item.shader;item.material.set_meta("source_polygon_offset_mode",item.mode)
 saved.clear();shaders.clear();weapon.arms.blend.restore();motion.restore()
