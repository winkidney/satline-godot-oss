extends RefCounted
const Planar=preload("res://scripts/planar_camera.gd")
const Interface=preload("res://scripts/planar_xr_interface.gd")
const Capture=preload("res://scripts/reflection_hdr_bridge.gd")
const MAIN_ONLY_LAYER=4
var owner:Node3D
var scene:SaltlineSourceScene
var viewport:SubViewport
var camera:Camera3D
var capture
var interface
var previous_interface:XRInterface
var ground:ShaderMaterial
var excluded=[]
var enabled=true
var quality_scale=.5
var render_size=Vector2i.ZERO
var initialized=false
var config={}
var report={}
func _projection(view:Camera3D)->Projection:
 var p=view.get_camera_projection();var n=view.near;var f=view.far
 return Projection(Vector4(absf(p.x.x),0,0,0),Vector4(0,absf(p.y.y),0,0),Vector4(0,0,-(f+n)/(f-n),-1),Vector4(0,0,-2*f*n/(f-n),0))
# Reserve this viewport before the sun caster viewport: source reflection reads its previous map.
func setup(parent:Node3D,source:SaltlineSourceScene,view:Camera3D)->bool:
 if not str(Engine.get_version_info().status).contains("saltline_oblique"):
  push_warning("Source planar reflection requires the isolated saltline_oblique engine build");return false
 previous_interface=XRServer.primary_interface
 if previous_interface!=null and previous_interface.is_initialized():push_warning("Source planar reflection not installed: another XR interface is initialized");return false
 owner=parent;scene=source
 for record in scene.source.materials:
  if record.name=="apron_wet":ground=scene.materials[record.id]
 if ground==null:return false
 config=Planar.compute(view.global_transform,_projection(view),Vector2i(owner.get_viewport().get_visible_rect().size),.5,true,view.far)
 viewport=SubViewport.new();viewport.size=config.size if config.active else Vector2i(640,360);viewport.world_3d=scene.get_world_3d();viewport.msaa_3d=Viewport.MSAA_DISABLED;viewport.use_taa=false;viewport.use_occlusion_culling=false;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;owner.add_child(viewport)
 RenderingServer.call("viewport_set_source_raster_y_up",viewport.get_viewport_rid(),true)
 camera=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.cull_mask=1;camera.near=view.near;camera.far=view.far
 camera.environment=scene.get_world_3d().environment.duplicate();camera.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment.tonemap_exposure=1;camera.environment.glow_enabled=false;camera.environment.ssao_enabled=false;camera.environment.ssil_enabled=false;camera.environment.ssr_enabled=false
 capture=Capture.new();capture.flip_y=true;capture.prepare_size(viewport.size);camera.compositor=Compositor.new();camera.compositor.compositor_effects=[capture]
 interface=Interface.new();interface.publish(config.world if config.active else Transform3D.IDENTITY,config.projection if config.active else _projection(view),viewport.size);XRServer.add_interface(interface)
 if not interface.initialize():camera.compositor=null;capture.dispose();viewport.queue_free();XRServer.remove_interface(interface);return false
 XRServer.primary_interface=interface;viewport.use_xr=true
 for record in scene.source.nodes:
  if record.name in ["apron","sea","rain","rainSplash"] and record.has("geometry"):
   var node:GeometryInstance3D=scene.source_nodes[record.id];excluded.append({"node":weakref(node),"world_layers":node.layers&5,"id":record.id,"name":record.name});node.layers=(node.layers&~1)|MAIN_ONLY_LAYER
 ground.set_shader_parameter("uRefl",capture.output);ground.set_shader_parameter("uReflOn",0.0);initialized=true;update(view);return true
# A real parent dependency preserves reflection-before-sun even after disposal/re-entry.
func order_before_sun(sun_viewport:SubViewport)->void:
 if initialized and viewport.get_parent()!=sun_viewport:
  viewport.reparent(sun_viewport);camera.make_current()

func update(view:Camera3D)->void:
 if not initialized:return
 config=Planar.compute(view.global_transform,_projection(view),render_size if render_size.x>0 else Vector2i(owner.get_viewport().get_visible_rect().size),quality_scale,enabled and quality_scale>0,view.far)
 if not config.active:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;ground.set_shader_parameter("uReflOn",0.0);report={"active":false};return
 if viewport.size!=config.size:viewport.size=config.size;capture.prepare_size(config.size)
 camera.global_transform=config.world;camera.near=view.near;camera.far=view.far;interface.publish(config.world,config.projection,config.size);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 ground.set_shader_parameter("uReflMatrix",config.sampling);ground.set_shader_parameter("uReflScale",config.scale);ground.set_shader_parameter("uReflLod",config.lod);ground.set_shader_parameter("uReflOn",1.0 if capture.is_ready() else 0.0)
 report={"active":true,"ready":capture.is_ready(),"size":[config.size.x,config.size.y],"lod":config.lod,"excluded":excluded.map(func(item):return item.name)}
func dispose()->void:
 if not initialized:return
 initialized=false;ground.set_shader_parameter("uReflOn",0.0)
 var image=Image.create(2,2,false,Image.FORMAT_RGBAF);image.fill(Color(0,0,0,1));ground.set_shader_parameter("uRefl",ImageTexture.create_from_image(image))
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;viewport.use_xr=false;camera.compositor=null;capture.dispose()
 if XRServer.primary_interface==interface:XRServer.primary_interface=previous_interface
 interface.uninitialize();XRServer.remove_interface(interface)
 for item in excluded:
  var node=item.node.get_ref()
  if node!=null:node.layers=(node.layers&~5)|item.world_layers
 excluded.clear();viewport.queue_free()
