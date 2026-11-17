extends SceneTree
const Planar=preload("res://scripts/planar_camera.gd")
const Interface=preload("res://scripts/planar_xr_interface.gd")
const Capture=preload("res://scripts/reflection_hdr_bridge.gd")
func _initialize()->void:call_deferred("run")
func compare(actual:Image,expected:Image)->Dictionary:
 var maximum=0.0;var mismatches=0;var count=0
 for y in actual.get_height():
  for x in actual.get_width():
   var error=absf(actual.get_pixel(x,y).r-expected.get_pixel(x,y).r);maximum=maxf(maximum,error)
   if error>.001:mismatches+=1
   if actual.get_pixel(x,y).r<.99:count+=1
 return {"maximum_error":maximum,"mismatches":mismatches,"covered_pixels":count}
func run()->void:
 var original=XRServer.primary_interface
 if original!=null and original.is_initialized():printerr("Active XR interface");quit(2);return
 var owner=Node3D.new();root.add_child(owner);root.disable_3d=true;var scene=SaltlineSourceScene.new();owner.add_child(scene);scene.source={"materials":[{"id":"fixture","props":{"side":2,"alphaTest":0.0}}]};scene.geometry_records["quad"]={"groups":[]}
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.WHITE;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;scene.get_world_3d().environment=environment
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-shadow-camera.json"));var light_world=scene._transform(config.cameraWorld)
 var primitive=QuadMesh.new();primitive.size=Vector2(config.width*.1,config.height*.14);var geometry=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,primitive.surface_get_arrays(0));var caster=MeshInstance3D.new();caster.mesh=geometry;scene.add_child(caster);caster.layers=1;caster.set_meta("source_id","caster");scene.records["caster"]={"id":"caster","geometry":"quad","materials":["fixture"],"layers":1,"castShadow":true};caster.global_transform=light_world*Transform3D(Basis.IDENTITY,Vector3(0,0,-(config.near+.5*(config.far-config.near))))
 var shadow=SaltlineSunShadowPass.new();shadow.setup(owner,scene,128)
 var reflection=SubViewport.new();reflection.size=Vector2i(128,128);reflection.world_3d=scene.get_world_3d();reflection.render_target_update_mode=SubViewport.UPDATE_DISABLED;shadow.viewport.add_child(reflection)
 var reflected_camera=Camera3D.new();reflected_camera.near=.08;reflected_camera.far=900;reflection.add_child(reflected_camera);reflected_camera.current=true
 var t=tan(deg_to_rad(74.0)*.5);var n=.08;var f=900.0;var projection=Projection(Vector4(1/t,0,0,0),Vector4(0,1/t,0,0),Vector4(0,0,-(f+n)/(f-n),-1),Vector4(0,0,-2*f*n/(f-n),0));var pose=Transform3D(Basis.looking_at(Vector3(0,-.2,-1),Vector3.UP),Vector3(0,2,6));var planar=Planar.compute(pose,projection,reflection.size,1.0)
 var interface=Interface.new();interface.publish(planar.world,planar.projection,reflection.size);XRServer.add_interface(interface);interface.initialize();XRServer.primary_interface=interface;reflection.use_xr=true
 var capture=Capture.new();capture.prepare_size(reflection.size);reflected_camera.compositor=Compositor.new();reflected_camera.compositor.compositor_effects=[capture]
 var display=MeshInstance3D.new();display.mesh=QuadMesh.new();display.mesh.size=Vector2(2,2);display.layers=1;display.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;display.extra_cull_margin=1000;scene.add_child(display)
 var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled,fog_disabled;uniform sampler2D source_depth:filter_nearest,repeat_disable;void vertex(){POSITION=vec4(VERTEX.xy,.5,1.0);}void fragment(){ALBEDO=vec3(texture(source_depth,FRAGCOORD.xy/VIEWPORT_SIZE).r);}";var material=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("source_depth",shadow.depth.output);display.material_override=material
 var world=SubViewport.new();world.size=Vector2i(128,128);world.use_hdr_2d=true;world.world_3d=scene.get_world_3d();world.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(world);var camera=Camera3D.new();world.add_child(camera);camera.global_transform=pose;camera.current=true
 await RenderingServer.frame_post_draw
 var previous=shadow.depth.output.get_image();var offsets=[0.0,.12,-.08,.2,.04,-.12,.09,-.03];var failures=[];var reports=[];var separated=0
 reflection.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 for frame in offsets.size():
  caster.global_transform=light_world*Transform3D(Basis.IDENTITY,Vector3(offsets[frame]*config.width,0,-(config.near+.5*(config.far-config.near))))
  shadow.update();await RenderingServer.frame_post_draw
  var current=shadow.depth.output.get_image();var reflected=capture.output.get_image();var main_image=world.get_texture().get_image();var old_error=compare(reflected,previous);var main_error=compare(main_image,current);var distinguishing=compare(current,previous)
  if old_error.mismatches>0:failures.append({"frame":frame,"check":"reflection must sample previous map","data":old_error})
  if main_error.mismatches>0:failures.append({"frame":frame,"check":"world must sample current map","data":main_error})
  if frame%2==0 and distinguishing.mismatches>20:separated+=1
  if frame%2==1 and distinguishing.mismatches>0:failures.append({"frame":frame,"check":"odd frame must hold shadow map"})
  reports.append({"frame":frame,"offset":offsets[frame],"updated":frame%2==0,"reflection_vs_previous":old_error,"world_vs_current":main_error,"current_vs_previous":distinguishing});previous=current
 if separated!=4:failures.append("fixture did not distinguish all four update frames")
 reflection.render_target_update_mode=SubViewport.UPDATE_DISABLED;world.render_target_update_mode=SubViewport.UPDATE_DISABLED;reflected_camera.compositor=null;capture.dispose();reflection.use_xr=false;XRServer.primary_interface=original;interface.uninitialize();XRServer.remove_interface(interface)
 var safe=Image.create(2,2,false,Image.FORMAT_RF);safe.fill(Color.WHITE);material.set_shader_parameter("source_depth",ImageTexture.create_from_image(safe));shadow.dispose()
 var report={"engine":Engine.get_version_info(),"frames":reports,"distinguished_update_frames":separated,"failures":failures,"scope":"Actual sourceSunShadowPass128 R32F, nonperiodic moving original caster proxy, actual 3D fragment samples shared shadow texture in reflection HDR before sun update and main HDR after. Explicit reflection child-of-sun viewport dependency. Full128x128 scalar comparisons tolerance.001 accounts RGBA16F storage. Original every-other-frame cadence, includes initial clear. Diagnostic fullscreen depth display, not PCSS final image or fullscene animation parity."};var file=FileAccess.open("res://evidence/planar-shadow-history-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
