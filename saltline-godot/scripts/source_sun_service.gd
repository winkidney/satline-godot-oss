extends RefCounted
# Per-object migration: only fully supported surfaces leave the native sun's layer.
const Planar=preload("res://scripts/planar_camera.gd")
const NATIVE_SUN_LAYER=1<<19
const SUPPORTED=["res://shaders/source_material.gdshader","res://shaders/source_material_alpha.gdshader","res://shaders/ground.gdshader","res://shaders/sea.gdshader","res://shaders/arms.gdshader"]
const BASIC=["res://shaders/source_material_basic.gdshader","res://shaders/source_material_basic_alpha.gdshader"]
var owner:Node3D
var scene:SaltlineSourceScene
var shadow:SaltlineSunShadowPass
var native_sun:DirectionalLight3D
var bound_materials={}
var ready=false
var enabled=true
var radiance_enabled=true
var shadows_enabled=true
var report={}
func setup(parent:Node3D,source:SaltlineSourceScene,source_shadow:SaltlineSunShadowPass,sun:DirectionalLight3D)->void:
 owner=parent;scene=source;shadow=source_shadow;native_sun=sun;native_sun.light_cull_mask=NATIVE_SUN_LAYER;update()
func _path(material:Material)->String:
 return str(material.shader.get_meta("source_shader_path",material.shader.resource_path)) if material is ShaderMaterial and material.shader!=null else ""
func _materials(node:GeometryInstance3D)->Array:
 var result=[]
 if node.material_override!=null:return [node.material_override]
 if node is MeshInstance3D and node.mesh!=null:
  for surface in node.mesh.get_surface_count():result.append(node.get_active_material(surface))
 elif node is MultiMeshInstance3D and node.multimesh!=null and node.multimesh.mesh!=null:
  for surface in node.multimesh.mesh.get_surface_count():result.append(node.multimesh.mesh.surface_get_material(surface))
 return result
func _bind(material:ShaderMaterial)->void:
 var id=material.get_instance_id()
 if bound_materials.has(id) and bound_materials[id].get_ref()==material:return
 material.set_shader_parameter("source_sun_shadow",shadow.depth.output);material.set_shader_parameter("source_sun_shadow_matrix",Planar.matrix(shadow.config.shadowMatrix));material.set_shader_parameter("source_sun_shadow_size",Vector2(shadow.viewport.size));material.set_shader_parameter("source_sun_ready",ready);bound_materials[id]=weakref(material)
func _visit(node:Node)->void:
 if node is GeometryInstance3D and node.get_world_3d()==scene.get_world_3d():
  var mats=_materials(node);var supported=not mats.is_empty();var lit=false
  for material in mats:
   var path=_path(material)
   if path in SUPPORTED:lit=true;_bind(material)
   elif path not in BASIC:supported=false
  var active=enabled and supported and lit
  if active:
   node.layers&=~NATIVE_SUN_LAYER;node.set_instance_shader_parameter("source_sun_active",true)
   var record=scene.records.get(str(node.get_meta("source_id","")),{})
   node.set_instance_shader_parameter("source_sun_receive_shadow",bool(record.get("receiveShadow",true)) and shadows_enabled)
   report.migrated+=1
   if bool(record.get("receiveShadow",true)):report.receivers+=1
   else:report.nonreceivers+=1
  else:
   node.layers|=NATIVE_SUN_LAYER
   if lit:node.set_instance_shader_parameter("source_sun_active",false)
   report.native+=1
 for child in node.get_children():_visit(child)
func update()->void:
  # Sun renders before the world. A warm map resize must not extinguish solar BRDF.
 var next_ready=(shadow.depth.is_ready_for(shadow.viewport.size) or shadow.resize_pending) and radiance_enabled
 if next_ready!=ready:
  ready=next_ready
  for id in bound_materials.keys():
   var material=bound_materials[id].get_ref()
   if material==null:bound_materials.erase(id)
   else:material.set_shader_parameter("source_sun_ready",ready)
 report={"migrated":0,"receivers":0,"nonreceivers":0,"native":0};_visit(owner)
func dispose()->void:
 var image=Image.create(2,2,false,Image.FORMAT_RF);image.fill(Color(1,0,0,1));var fallback=ImageTexture.create_from_image(image)
 for id in bound_materials:
  var material=bound_materials[id].get_ref()
  if material!=null:material.set_shader_parameter("source_sun_ready",false);material.set_shader_parameter("source_sun_shadow",fallback)
 bound_materials.clear()
