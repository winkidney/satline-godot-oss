extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var group=Node3D.new();viewport.add_child(group)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 var sky=Sky.new();sky.process_mode=Sky.PROCESS_MODE_REALTIME;var sky_material=ProceduralSkyMaterial.new();sky.sky_material=sky_material;environment.sky=sky;viewport.world_3d.environment=environment
 var camera=Camera3D.new();group.add_child(camera);camera.position=Vector3(0,0,3);camera.current=true
 var scene=SaltlineSourceScene.new();scene.source={"modules":{"level":{"interiorBoxes":[]}}};group.add_child(scene);var material=scene._material({"id":"diagnostic","name":"ibl-isolation","type":"MeshStandardMaterial","props":{"color":[.35,.2,.1],"metalness":.4,"roughness":.35},"userData":{}});scene.materials.diagnostic=material
 var instance=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(2,2);instance.mesh=quad;instance.material_override=material;group.add_child(instance);var service=preload("res://scripts/source_ibl_service.gd").new();service.setup(group,scene,camera);var results=[];var failures=[]
 for ready in [true,false]:
  var images=[];material.set_shader_parameter("source_ibl_ready",ready)
  for energy in [0.0,10.0]:
   environment.ambient_light_energy=energy;sky_material.sky_energy_multiplier=energy;sky_material.ground_energy_multiplier=energy
   for warm in 16:service.update(0.0);await RenderingServer.frame_post_draw
   images.append(viewport.get_texture().get_image())
  var maximum=0.0;var changed=0
  for y in range(24,40):
   for x in range(24,40):
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta)
    if delta>.001:changed+=1
  results.append({"source_ibl_ready":ready,"maximum_rgb_difference":maximum,"changed_pixels":changed})
  if ready and maximum>.001:failures.append("native environment added on top of source IBL")
  if not ready and changed<20:failures.append("native lighting control was ineffective")
 var report={"results":results,"failures":failures,"scope":"Actual generic Standard factory,sourceIBL service and spatialQuad;vary native ambient and native proceduralSky reflection energy0to10. Source-ready path must be invariant,readyfalse proves native control effective. NoGI/probe/SSIL/SSR in this scene."};FileAccess.open("res://evidence/ibl-native-suppression-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));service.dispose();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
