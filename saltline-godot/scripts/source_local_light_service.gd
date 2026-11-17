extends RefCounted
const Sun=preload("res://scripts/source_sun_service.gd")
const WORLD_FALLBACK=1<<18
const WEAPON_FALLBACK=1<<17
var owner:Node3D
var scene:SaltlineSourceScene
var data
var bound={}
var original_masks=[]
var enabled=true
var radiance_enabled=true
var report={}
func setup(parent:Node3D,source:SaltlineSourceScene,source_data)->void:
 owner=parent;scene=source;data=source_data
 for light in data.lights:original_masks.append(light.light_cull_mask)
 update()
func _path(material:Material)->String:
 return str(material.shader.get_meta("source_shader_path",material.shader.resource_path)) if material is ShaderMaterial and material.shader!=null else ""
func _materials(node:GeometryInstance3D)->Array:
 if node.material_override!=null:return [node.material_override]
 var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null
 var result=[]
 if mesh!=null:
  for surface in mesh.get_surface_count():result.append(node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
 return result
func _bind(material:ShaderMaterial)->void:
 var id=material.get_instance_id()
 if not bound.has(id) or bound[id].get_ref()!=material:
  material.set_shader_parameter("source_local_lights",data.texture);bound[id]=weakref(material)
 material.set_shader_parameter("source_local_ready",enabled);material.set_shader_parameter("source_local_radiance_enabled",radiance_enabled)
func _visit(node:Node,restore:bool=false)->void:
 # During Main._exit_tree, the source subtree has already left its World3D.
 # Detached instances are being freed; only live instances need mask restoration.
 if not is_instance_valid(scene) or not scene.is_inside_tree():return
 if node is GeometryInstance3D and node.is_inside_tree() and node.get_world_3d()==scene.get_world_3d():
  var materials=_materials(node);var supported=not materials.is_empty();var lit=false
  for material in materials:
   var path=_path(material)
   if path in Sun.SUPPORTED:
    lit=true
    if not restore:_bind(material)
   elif path not in Sun.BASIC:supported=false
  var active=not restore and enabled and supported and lit
  node.layers&=~(WORLD_FALLBACK|WEAPON_FALLBACK)
  if not active and not restore:
   if (node.layers&5)!=0:node.layers|=WORLD_FALLBACK
   if (node.layers&2)!=0:node.layers|=WEAPON_FALLBACK
  if lit:
   node.set_instance_shader_parameter("source_local_active",active)
  if active:report.migrated+=1
  elif not restore:report.native+=1
 for child in node.get_children():_visit(child,restore)
func update()->void:
 for index in data.lights.size():data.lights[index].light_cull_mask=(WORLD_FALLBACK|WEAPON_FALLBACK if index<10 else WEAPON_FALLBACK) if enabled else original_masks[index]
 report={"migrated":0,"native":0};_visit(owner)
 var stale=[]
 for id in bound:
  if bound[id].get_ref()==null:stale.append(id)
 for id in stale:bound.erase(id)
func dispose()->void:
 for index in data.lights.size():data.lights[index].light_cull_mask=original_masks[index]
 _visit(owner,true)
 for reference in bound.values():
  var material=reference.get_ref()
  if material!=null:material.set_shader_parameter("source_local_ready",false);material.set_shader_parameter("source_local_lights",null)
 bound.clear()
