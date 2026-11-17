extends SceneTree
const Planar=preload("res://scripts/planar_camera.gd")
const Interface=preload("res://scripts/planar_xr_interface.gd")
func _initialize()->void:call_deferred("run")
func box(scene:Node3D,position:Vector3,size:Vector3)->void:
 var mesh=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=size;mesh.position=position;var material=StandardMaterial3D.new();material.albedo_color=Color(.6,.65,.7);material.roughness=.6;mesh.material_override=material;scene.add_child(mesh)
func run()->void:
 var original=XRServer.primary_interface
 if original!=null and original.is_initialized():printerr("Active XR session");quit(2);return
 var viewport=SubViewport.new();viewport.size=Vector2i(512,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var scene=Node3D.new();viewport.add_child(scene)
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.ambient_light_energy=0;scene.add_child(environment)
 for z in [0,-4,-10,-20,-40]:
  for x in [-4,-1,2,5]:box(scene,Vector3(x,1.2,z),Vector3(1.0,2.2,1.0))
 # Source reflection hides its ground; an opaque test floor would occlude the whole mirrored view.
 box(scene,Vector3(0,2,-8),Vector3(6,3.8,.3))
 box(scene,Vector3(0,4,-6),Vector3(2,1,.7))
 var camera=Camera3D.new();viewport.add_child(camera);camera.near=.08;camera.far=900;camera.fov=74;camera.current=true
 var world=Transform3D(Basis.looking_at(Vector3(0,0 if "--horizontal" in OS.get_cmdline_user_args() else -.2,-1),Vector3.UP),Vector3(0,2,8));var t=tan(deg_to_rad(74.0)*.5);var n=.08;var f=900.0;var projection=Projection(Vector4(1/(t*2),0,0,0),Vector4(0,1/t,0,0),Vector4(0,0,-(f+n)/(f-n),-1),Vector4(0,0,-2*f*n/(f-n),0));var setup=Planar.compute(world,projection,viewport.size,1.0)
 var interface=Interface.new();interface.publish(setup.world,projection,viewport.size);XRServer.add_interface(interface);interface.initialize();XRServer.primary_interface=interface;viewport.use_xr=true
 var omni=[];var spot=[]
 for z in [1,-7,-18,-36]:
  var light=OmniLight3D.new();light.position=Vector3(-1,3,z);light.omni_range=8;light.light_energy=5;scene.add_child(light);omni.append(light)
  var cone=SpotLight3D.new();scene.add_child(cone);cone.position=Vector3(2,5,z+2);cone.look_at(Vector3(0,.1,z-2));cone.spot_range=14;cone.spot_angle=50;cone.light_energy=8;spot.append(cone)
 var sun=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-45,-30,0);sun.light_energy=2;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS;sun.directional_shadow_max_distance=100
 var failures=[];var reports=[];var sun_images=[]
 for mode in ["omni","spot","sun","sun_shadow"]:
  for light in omni:light.visible=mode=="omni"
  for light in spot:light.visible=mode=="spot"
  sun.visible=mode in ["sun","sun_shadow"];sun.shadow_enabled=mode=="sun_shadow"
  var images=[]
  for clipped in [false,true]:
   interface.publish(setup.world,setup.projection if clipped else projection,viewport.size)
   for warm in 8:await RenderingServer.frame_post_draw
   var image=viewport.get_texture().get_image();image.save_png("res://evidence/planar-light-%s-%s.png"%[mode,str(clipped)]);images.append(image)
  if mode in ["sun","sun_shadow"]:sun_images.append(images[0])
  var changed=0;var lit=0;var maximum=0.0;var total=0.0
  for y in viewport.size.y:
   for x in viewport.size.x:
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var difference=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)));maximum=maxf(maximum,difference);total+=difference
    if maxf(a.r,maxf(a.g,a.b))>.03:lit+=1
    if difference>2.0/255:changed+=1
  if lit<100:failures.append(mode+": fixture not lit")
  if changed>0:failures.append(mode+": oblique projection changes lighting")
  reports.append({"mode":mode,"lit_pixels":lit,"changed_pixels":changed,"maximum_error":maximum,"mean_error":total/(viewport.size.x*viewport.size.y)})
 var shadow_pixels=0
 for y in viewport.size.y:
  for x in viewport.size.x:
   var a=sun_images[0].get_pixel(x,y);var b=sun_images[1].get_pixel(x,y)
   if a.r-b.r>2.0/255:shadow_pixels+=1
 if shadow_pixels<10:failures.append("shadow fixture has no measurable shadow contribution")
 viewport.use_xr=false;XRServer.primary_interface=original;interface.uninitialize();XRServer.remove_interface(interface)
 var report={"engine":Engine.get_version_info(),"horizontal":"--horizontal" in OS.get_cmdline_user_args(),"cases":reports,"shadow_darkened_pixels":shadow_pixels,"normal_near_far":[projection.get_z_near(),projection.get_z_far()],"oblique_near_far":[setup.projection.get_z_near(),setup.projection.get_z_far()],"failures":failures,"scope":"Native Forward+ XR reflected above-plane PBR world at depths0..40, compare same reflected pose normalGL vs sourceoblique projection. Separate omni,spot,sun,4split-shadow; all geometry above plane, no post. Difference threshold2/255. Diagnostic transport acceptance, not original lighting parity."};var file=FileAccess.open("res://evidence/planar-xr-lighting%s-verification.json"%("-horizontal" if "--horizontal" in OS.get_cmdline_user_args() else "-patched" if str(Engine.get_version_info().status).contains("saltline_oblique") else ""),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
