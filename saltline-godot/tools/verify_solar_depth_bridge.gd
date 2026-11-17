extends SceneTree
func _initialize()->void:call_deferred("run")
func quad(owner:Node3D,position:Vector3,layer:int)->MeshInstance3D:
 var mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(.8,.8);mesh.position=position;mesh.layers=layer
 var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material;owner.add_child(mesh);return mesh
func port(owner:Node3D,layer:int,weapon:bool)->Dictionary:
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.world_3d=owner.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.position.z=3;camera.near=.08;camera.far=900;camera.cull_mask=layer;viewport.add_child(camera);camera.current=true
 var effect=SaltlineSolarDepthBridge.new();effect.weapon_mode=weapon;effect.prepare_size(viewport.size);var compositor=Compositor.new();compositor.compositor_effects=[effect];camera.compositor=compositor
 return {"viewport":viewport,"camera":camera,"effect":effect}
func run()->void:
 var owner=Node3D.new();root.add_child(owner)
 var world=port(owner,1,false);var weapon=port(owner,2,true)
 var world_mesh=quad(owner,Vector3(-1,1,0),1);var weapon_mesh=quad(owner,Vector3(1,-1,0),2)
 var glass=quad(owner,Vector3(1,1,0),1);var glass_material=StandardMaterial3D.new();glass_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass_material.albedo_color=Color(1,1,1,.4);glass_material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED;glass.material_override=glass_material
 var cutout=quad(owner,Vector3(-1,-1,0),1);var cutout_shader=Shader.new();cutout_shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){if(UV.x<.5)discard;ALBEDO=vec3(1.0);}"
 var cutout_material=ShaderMaterial.new();cutout_material.shader=cutout_shader;cutout.material_override=cutout_material
 print("PHASE warmup")
 for frame in 5:await process_frame
 await RenderingServer.frame_post_draw
 var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;uniform sampler2D tWorld:filter_nearest,repeat_disable;uniform sampler2D tWeapon:filter_nearest,repeat_disable;void fragment(){float w=texture(tWorld,UV).r;float v=texture(tWeapon,UV).r;COLOR=vec4(w,v,min(w,v),1.0);}"
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport);var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("tWorld",world.effect.output);material.set_shader_parameter("tWeapon",weapon.effect.output);var rect=ColorRect.new();rect.size=Vector2(64,64);rect.material=material;viewport.add_child(rect)
 var seed=Image.create(2,2,false,Image.FORMAT_RGBAF);seed.fill(Color(.12,0,0,1));var seed_texture=ImageTexture.create_from_image(seed)
 var solar=pipeline._filter(Vector2i(2,2),"res://shaders/source_adapt.gdshader",{"tPrev":seed_texture,"tLum":seed_texture,"tDepth":world.effect.output,"tWeaponSolarDepth":weapon.effect.output,"uUseWeaponDepth":true,"uSunOn":1.0,"uRate":1.0,"uVisRate":1.0,"uAspect":1.0})
 print("PHASE consumer")
 var failures=[];var samples=[];var pattern=[0,3,1,0,2,3,2,0,1,3,0]
 for index in pattern.size():
  var mask=pattern[index];solar.material.set_shader_parameter("uSunUv",Vector2(.25,.75) if index%2==0 else Vector2(.75,.25));world_mesh.visible=bool(mask&1);weapon_mesh.visible=bool(mask&2)
  await RenderingServer.frame_post_draw
  var visibility=solar.viewport.get_texture().get_image().get_pixel(0,0).g
  var visible_expected=0.0 if bool(mask&(1 if index%2==0 else 2)) else 1.0
  if visibility!=visible_expected:failures.append({"frame":index,"solar_visibility":visibility,"expected":visible_expected})
  var image=viewport.get_texture().get_image();var top=image.get_pixel(16,16);var bottom=image.get_pixel(48,48);var clear=image.get_pixel(48,16)
  var hole=image.get_pixel(13,48);var solid=image.get_pixel(19,48)
  if hole.r<.99999 or solid.r>.99999:failures.append({"frame":index,"hole":hole.r,"solid":solid.r})
  var expected_world=not bool(mask&1);var expected_weapon=not bool(mask&2)
  if (top.r>.99999)!=expected_world or top.g<.99999 or (bottom.g>.99999)!=expected_weapon or bottom.r<.99999 or clear.r<.99999 or clear.g<.99999:failures.append({"frame":index,"mask":mask,"top":[top.r,top.g],"bottom":[bottom.r,bottom.g],"clear":[clear.r,clear.g]})
  samples.append({"frame":index,"mask":mask,"solar_visibility":visibility,"top":[top.r,top.g,top.b],"bottom":[bottom.r,bottom.g,bottom.b],"clear":[clear.r,clear.g,clear.b]})
 print("PHASE resize")
 var wrapper=world.effect.output;var wrapper_rid=wrapper.get_rid();world.effect.prepare_size(Vector2i(96,80));weapon.effect.prepare_size(Vector2i(80,96));world.viewport.size=Vector2i(96,80);weapon.viewport.size=Vector2i(80,96);world_mesh.visible=true;weapon_mesh.visible=true
 await RenderingServer.frame_post_draw
 var world_size=world.effect.output.get_size();var weapon_size=weapon.effect.output.get_size()
 var position=world.camera.unproject_position(world_mesh.global_position)/Vector2(world.viewport.size)*64
 var resized=viewport.get_texture().get_image().get_pixelv(Vector2i(position))
 if world_size!=Vector2(96,80) or weapon_size!=Vector2(80,96) or wrapper!=world.effect.output or wrapper_rid!=wrapper.get_rid() or resized.r>.99999:failures.append("Resize/wrapper/consumer binding failed")
 var raw=world.effect.output.get_image();raw.save_exr("res://evidence/solar-world-depth.exr",false)
 var report={"frames":pattern.size(),"failures":failures,"samples":samples,"resize_world":[world_size.x,world_size.y],"resize_weapon":[weapon_size.x,weapon_size.y],"persistent_wrapper":wrapper_rid==wrapper.get_rid(),"raw_format":raw.get_format(),"raw_size":[raw.get_width(),raw.get_height()],"scope":"Actual world/weapon CompositorEffect POST_TRANSPARENT resolved depth to R32F Texture2DRD; later2D consumer and actualQ912-tap visibility verify same-frame nonperiodic occluder masks, top-left world and bottom-right weapon orientation, clear=1. Orthographic64x64 MSAAoff controlled opaque quads, transparent non-depth-writing glass, discard cutout holes, independent96x80/80x96 resize and persistent wrapper consumer binding. Real source materials and MSAA4 edge parity not tested."}
 var file=FileAccess.open("res://evidence/solar-depth-bridge-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report))
 print("PHASE cleanup")
 world.camera.compositor=null;weapon.camera.compositor=null;solar.material.set_shader_parameter("tDepth",seed_texture);solar.material.set_shader_parameter("tWeaponSolarDepth",seed_texture);material.set_shader_parameter("tWorld",null);material.set_shader_parameter("tWeapon",null);world.effect.dispose();weapon.effect.dispose()
 for frame in 3:await process_frame
 owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
