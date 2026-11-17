class_name SaltlineSunShadowPass
extends RefCounted

var owner:Node3D
var source_scene:SaltlineSourceScene
var viewport:SubViewport
var camera:Camera3D
var root:Node3D
var depth:SaltlineSolarDepthBridge
var config:Dictionary
var bindings={}
var material_records={}
var depth_materials={}
var frame=0
var updates=0
var every_frame=false
var force_pending=false
var resize_pending=false
var report={"eligible":0,"visible":0,"mesh":0,"multimesh":0,"skin":0,"unsupported":[]}

func set_resolution(resolution:int)->void:
 var size=Vector2i(resolution,resolution)
 if viewport.size==size:return
  # Preserve valid warm radiance until the ordered sun pass writes the replacement.
 resize_pending=depth.is_ready_for(viewport.size) or resize_pending
  # Let the normal frame update consume this; an extra update here can cancel ONCE.
 viewport.size=size;depth.prepare_size(size);force_pending=true

func setup(parent:Node3D,scene:SaltlineSourceScene,resolution:int=4096)->void:
 owner=parent;source_scene=scene;config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-shadow-camera.json"))
 for record in scene.source.materials:material_records[record.id]=record
 viewport=SubViewport.new();viewport.size=Vector2i(resolution,resolution);viewport.world_3d=World3D.new();viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.use_taa=false;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;owner.add_child(viewport)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.WHITE;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 root=Node3D.new();viewport.add_child(root)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.size=maxf(config.width,config.height);camera.near=config.near;camera.far=config.far;camera.cull_mask=1;root.add_child(camera);camera.global_transform=source_scene._transform(config.cameraWorld);camera.current=true
 depth=SaltlineSolarDepthBridge.new();depth.prepare_size(viewport.size);var compositor=Compositor.new();compositor.compositor_effects=[depth];camera.compositor=compositor
 sync_casters()

func _material(id:String)->ShaderMaterial:
 if depth_materials.has(id):return depth_materials[id]
 var record=material_records[id];var props=record.props
 var side=int(props.get("side",0));var shadow_side=props.get("shadowSide")
 if shadow_side==null:shadow_side=1 if side==0 else 0 if side==1 else 2
 var shader=ShaderMaterial.new();shader.shader=load("res://shaders/shadow_depth_"+(["front","back","double"][int(shadow_side)])+".gdshader")
 var size=maxf(config.width,config.height);shader.set_shader_parameter("shadow_projection_scale",Vector2(size/config.width,size/config.height));shader.set_shader_parameter("alpha_cut",props.get("alphaTest",0.0));shader.set_shader_parameter("opacity_value",props.get("opacity",1.0))
 var texture=source_scene._texture(props.get("map"));shader.set_shader_parameter("has_map",texture!=null)
 if texture!=null:
  shader.set_shader_parameter("alpha_tex",texture);var info=source_scene.texture_records[props.map["$texture"]];shader.set_shader_parameter("uv_repeat",Vector2(info.repeat[0],info.repeat[1]));shader.set_shader_parameter("uv_offset",Vector2(info.offset[0],info.offset[1]))
 var alpha=source_scene._texture(props.get("alphaMap"));shader.set_shader_parameter("has_alpha_map",alpha!=null)
 if alpha!=null:shader.set_shader_parameter("alpha_map",alpha)
 depth_materials[id]=shader;return shader

func _find(node:Node,result:Array)->void:
 if node is GeometryInstance3D and node.has_meta("source_id"):
  var id=str(node.get_meta("source_id"));var record=source_scene.records.get(id,{})
  if record.has("geometry") and (int(node.layers)&1)!=0 and node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:result.append(node)
 for child in node.get_children():_find(child,result)

func _make(source:GeometryInstance3D,record:Dictionary)->Dictionary:
 var proxy:GeometryInstance3D
 if source is MeshInstance3D:
  var mesh=MeshInstance3D.new();mesh.mesh=source.mesh;proxy=mesh
  for surface in mesh.mesh.get_surface_count():
   var slot=0 if record.materials.size()==1 else int(source_scene.geometry_records[record.geometry].groups[surface].materialIndex)
   mesh.set_surface_override_material(surface,_material(record.materials[slot]))
 elif source is MultiMeshInstance3D:
  var multi=MultiMeshInstance3D.new();multi.multimesh=source.multimesh;proxy=multi
  if record.materials.size()!=1:report.unsupported.append("MultiMesh multi-material "+record.id);return {}
  multi.material_override=_material(record.materials[0])
 else:report.unsupported.append("Unknown caster "+record.id);return {}
 proxy.layers=1;proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(proxy)
 return {"source":weakref(source),"proxy":proxy,"id":record.id}

func sync_casters()->void:
 var casters=[];_find(source_scene,casters);var live={};var visible=0;var meshes=0;var multis=0;var skins=0
 for source in casters:
  var key=source.get_instance_id();live[key]=true
  if not bindings.has(key):
   var binding=_make(source,source_scene.records[str(source.get_meta("source_id"))])
   if binding.is_empty():continue
   bindings[key]=binding
  var proxy=bindings[key].proxy;proxy.global_transform=source.global_transform;proxy.visible=source.is_visible_in_tree() and source.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  if proxy.visible:visible+=1
  if source is MeshInstance3D:
   meshes+=1
   if source.skin!=null:
    skins+=1;proxy.skin=source.skin
    if source.has_node(source.skeleton):proxy.skeleton=proxy.get_path_to(source.get_node(source.skeleton))
   for shape in source.mesh.get_blend_shape_count():proxy.set_blend_shape_value(shape,source.get_blend_shape_value(shape))
  else:multis+=1;proxy.multimesh=source.multimesh
 for key in bindings.keys():
  if not live.has(key):bindings[key].proxy.queue_free();bindings.erase(key)
 report.eligible=bindings.size();report.visible=visible;report.mesh=meshes;report.multimesh=multis;report.skin=skins

func update(force:bool=false)->void:
 if depth.is_ready_for(viewport.size):resize_pending=false
 var render=force or force_pending or every_frame or frame%2==0 or updates==0
 force_pending=false
 if render:sync_casters();viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;updates+=1
 else:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 frame+=1

func dispose()->void:
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;camera.compositor=null;depth.dispose();bindings.clear();depth_materials.clear();viewport.queue_free()
