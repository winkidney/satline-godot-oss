extends SceneTree
const Planar=preload("res://scripts/planar_camera.gd")
const Capture=preload("res://scripts/reflection_hdr_bridge.gd")
const Interface=preload("res://scripts/planar_xr_interface.gd")
func _initialize()->void:call_deferred("run")
func box(parent:Node3D,position:Vector3,color:Color)->void:
 var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=Vector3(1.2,.7,.5);mesh.position=position;var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;mesh.material_override=material
 if color==Color.GREEN:
  var hdr=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded;void fragment(){ALBEDO=vec3(0.0,4.0,0.0);}";hdr.shader=shader;mesh.material_override=hdr
 parent.add_child(mesh)
func count(image:Image)->Dictionary:
 var counts={"red":0,"green":0,"blue":0}
 for y in image.get_height():
  for x in image.get_width():
   var c=image.get_pixel(x,y)
   if c.r>.5 and c.g<.2:counts.red+=1
   if c.g>.5 and c.r<.2:counts.green+=1
   if c.b>.5 and c.r<.2 and c.g<.2:counts.blue+=1
 return counts
func run()->void:
 var engine_origin="--engine-origin" in OS.get_cmdline_user_args()
 var original=XRServer.primary_interface
 if original!=null and original.is_initialized():printerr("Active XR session: probe refuses to replace it");quit(2);return
 var viewport=SubViewport.new();viewport.size=Vector2i(256,128);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 if engine_origin:RenderingServer.viewport_set_source_raster_y_up(viewport.get_viewport_rid(),true)
 var scene=Node3D.new();viewport.add_child(scene);box(scene,Vector3(-1.4,.8,-2),Color.GREEN);box(scene,Vector3(1.4,-.8,-2),Color.RED);box(scene,Vector3(0,1.8,-3),Color.BLUE)
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var camera=Camera3D.new();viewport.add_child(camera);camera.near=.08;camera.far=900;camera.fov=74;camera.current=true
 var capture=Capture.new();capture.flip_y=engine_origin;capture.prepare_size(viewport.size);camera.compositor=Compositor.new();camera.compositor.compositor_effects=[capture]
 var main=SubViewport.new();main.size=viewport.size;main.world_3d=viewport.world_3d;main.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(main);var main_camera=Camera3D.new();main.add_child(main_camera);main_camera.position=Vector3(0,2,6);main_camera.look_at(Vector3(0,2 if "--horizontal" in OS.get_cmdline_user_args() else 0,-2));main_camera.current=true
 var pose=main_camera.global_transform;var t=tan(deg_to_rad(74.0)*.5);var n=.08;var f=900.0
 var projection=Projection(Vector4(1/(t*2),0,0,0),Vector4(0,1/t,0,0),Vector4(0,0,-(f+n)/(f-n),-1),Vector4(0,0,-2*f*n/(f-n),0))
 var setup=Planar.compute(pose,projection,viewport.size,1.0);var interface=Interface.new();interface.publish(setup.world,projection,viewport.size);XRServer.add_interface(interface)
 if not interface.initialize():printerr("XR interface initialize failed");XRServer.remove_interface(interface);quit(2);return
 XRServer.primary_interface=interface;viewport.use_xr=true
 var reports=[];var main_images=[];var normalized_image:Image
 for clipped in [false,true,false]:
  interface.publish(setup.world,setup.projection if clipped else projection,viewport.size)
  for warm in 6:await process_frame;RenderingServer.force_draw(false)
  var image=viewport.get_texture().get_image()
  if engine_origin:image.flip_y()
  normalized_image=image
  image.save_png("res://evidence/planar-xr-%d.png"%reports.size());reports.append({"clipped":clipped,"counts":count(image),"size":[image.get_width(),image.get_height()]});main_images.append(main.get_texture().get_image().get_data())
 var hdr_image=capture.output.get_image();var maximum_green=0.0
 for y in hdr_image.get_height():
  for x in hdr_image.get_width():maximum_green=maxf(maximum_green,hdr_image.get_pixel(x,y).g)
 var mip_count=hdr_image.get_mipmap_count();var last_mip_green=0.0
 if hdr_image.has_mipmaps() and hdr_image.get_format()==Image.FORMAT_RGBAH:
  var last=Image.create_from_data(1,1,false,Image.FORMAT_RGBAH,hdr_image.get_data().slice(hdr_image.get_data().size()-8));last_mip_green=last.get_pixel(0,0).g
 var orientation_mismatches=0
 for y in hdr_image.get_height():
  for x in hdr_image.get_width():
   var a=normalized_image.get_pixel(x,y);var b=hdr_image.get_pixel(x,y)
   if Vector3(float(a.r>.5),float(a.g>.5),float(a.b>.5))!=Vector3(float(b.r>.5),float(b.g>.5),float(b.b>.5)):orientation_mismatches+=1
 var failures=[]
 if orientation_mismatches>0:failures.append("HDR level0 orientation differs from normalized viewport")
 if mip_count!=8 or last_mip_green<=0:failures.append("HDR copy mip chain missing or empty")
 if maximum_green<3.9 or maximum_green>4.1:failures.append("HDR copy did not preserve green4")
 if interface.projection_calls==0:failures.append("projection callback unused")
 if reports[0].counts.red<10:failures.append("unclipped lower marker missing")
 if reports[1].counts.red>0:failures.append("below-plane marker not clipped")
 if reports[1].counts.green<10 or reports[1].counts.blue<10:failures.append("above-plane markers incorrectly clipped")
 if reports[0].counts!=reports[2].counts:failures.append("projection restore changed raster")
 if main_images[0]!=main_images[1] or main_images[1]!=main_images[2]:failures.append("non-XR main viewport changed")
 var capture_ready=capture.is_ready()
 capture.dispose();camera.compositor.compositor_effects=[]
 viewport.use_xr=false;XRServer.primary_interface=original;interface.uninitialize();XRServer.remove_interface(interface)
 var report={"engine_origin":engine_origin,"level0_orientation_mismatches":orientation_mismatches,"cases":reports,"maximum_green_hdr":maximum_green,"generated_mips":mip_count,"last_mip_green":last_mip_green,"engine":Engine.get_version_info(),"horizontal":"--horizontal" in OS.get_cmdline_user_args(),"capture_ready":capture_ready,"projection_calls":interface.projection_calls,"failures":failures,"scope":"Experimental mono XR projection transport: actual unshaded above/below-plane markers, original oblique matrix, isolated non-XR main viewport byte comparison, switch and restore. POST_TRANSPARENT RGBA16F copy preserves unshaded green4. Includes actual generated HDR mip chain presence/nonzero tail; no PBR/cascade proof."};var file=FileAccess.open("res://evidence/planar-xr%s-verification.json"%("-origin" if engine_origin else "-horizontal" if "--horizontal" in OS.get_cmdline_user_args() else "-patched" if str(Engine.get_version_info().status).contains("saltline_oblique") else ""),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();main.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
