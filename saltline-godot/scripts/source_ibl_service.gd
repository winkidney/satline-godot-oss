extends RefCounted
const SUPPORTED=["res://shaders/source_material.gdshader","res://shaders/source_material_alpha.gdshader","res://shaders/ground.gdshader","res://shaders/sea.gdshader","res://shaders/arms.gdshader"]
var owner:Node3D
var scene:SaltlineSourceScene
var camera:Camera3D
var envs=preload("res://scripts/pmrem_textures.gd").new()
var bindings={}
var bound={}
var view_fill=1.1
var view_room=false
var radiance_enabled=true
var report={}
const SKY="30c27fd2-4d7a-42ce-8e91-2cd36adb3c40"
const ROOM="e44868bb-2bd3-41d6-978b-02a02fedbdf3"
func setup(parent:Node3D,source:SaltlineSourceScene,source_camera:Camera3D)->void:
 owner=parent;scene=source;camera=source_camera;envs.load_source()
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/environment-bindings.json"))
 view_fill=float(reference.get("view_fill",1.1))
 for record in reference.bindings:bindings[record.id]=record
 for material in scene.materials.values():_bind(material)
 update(0.0)
func _supported(material:Material)->bool:
 return material is ShaderMaterial and material.shader!=null and str(material.shader.get_meta("source_shader_path",material.shader.resource_path)) in SUPPORTED
func _bind(material:Material)->void:
 if not _supported(material):return
 var id=material.get_instance_id()
 if bound.has(id) and bound[id].get_ref()==material:return
 var origin=str(material.get_meta("source_material_id",""));var reference=bindings.get(origin,{});var explicit=reference.get("explicit_env")
 material.set_shader_parameter("source_ibl_sky",envs.textures[SKY]);material.set_shader_parameter("source_ibl_room",envs.textures[ROOM]);material.set_shader_parameter("source_ibl_explicit_room",explicit!=null and explicit.id==ROOM);material.set_shader_parameter("source_ibl_explicit_intensity",float(reference.get("env_intensity",1.0)));material.set_shader_parameter("source_ibl_ready",true);bound[id]=weakref(material)
func _materials(node:GeometryInstance3D)->Array:
 if node.material_override!=null:return [node.material_override]
 var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh!=null else null
 var result=[]
 if mesh!=null:
  for surface in mesh.get_surface_count():result.append(node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
 return result
func _visit(node:Node)->void:
 if node is GeometryInstance3D and node.get_world_3d()==scene.get_world_3d():
  var uses=false
  for material in _materials(node):
   if _supported(material):uses=true;_bind(material)
  if uses:
   var viewmodel=(node.layers&2)!=0;node.set_instance_shader_parameter("source_ibl_viewmodel",viewmodel);report.objects+=1
   if viewmodel:report.viewmodels+=1
 for child in node.get_children():_visit(child)
func inside(position:Vector3)->bool:
 var boxes=scene.source.modules.level.get("interiorBoxes",[])
 if boxes.is_empty():return false
 var box=boxes[0];return position.x>box.min[0] and position.x<box.max[0] and position.z>box.min[2] and position.z<box.max[2] and position.y<box.max[1]
func update(dt:float)->void:
 view_room=inside(camera.global_position)
 var forward=-camera.global_basis.z;var sun=Vector3(.9163473614874841,.22508532350948027,.33112552036283543);var facing=maxf(0.0,forward.x*sun.x+forward.z*sun.z);var target=1.1 if view_room else 1.1+.6*facing*facing;view_fill+=(target-view_fill)*minf(1.0,dt*2.5)
 report={"objects":0,"viewmodels":0,"materials":0,"view_fill":view_fill,"view_room":view_room,"radiance_enabled":radiance_enabled}
 _visit(owner)
 var stale=[]
 for id in bound:
  var material=bound[id].get_ref()
  if material==null:stale.append(id);continue
  material.set_shader_parameter("source_ibl_view_fill",view_fill);material.set_shader_parameter("source_ibl_view_room",view_room);material.set_shader_parameter("source_ibl_radiance_enabled",radiance_enabled);report.materials+=1
 for id in stale:bound.erase(id)
func dispose()->void:
 for reference in bound.values():
  var material=reference.get_ref()
  if material==null:continue
  material.set_shader_parameter("source_ibl_ready",false);material.set_shader_parameter("source_ibl_sky",null);material.set_shader_parameter("source_ibl_room",null)
 bound.clear();envs.textures.clear()
