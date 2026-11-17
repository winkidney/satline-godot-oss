extends SceneTree
func _initialize()->void:call_deferred("run")
func draw_game(game)->void:
 for warm in 3:
  game._process(0.0);await process_frame;RenderingServer.force_draw(false)
func difference(a:Image,b:Image)->Dictionary:
 var changed=0;var maximum=0.0
 for y in range(0,a.get_height(),4):
  for x in range(0,a.get_width(),4):
   var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);var delta=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b);maximum=maxf(maximum,delta)
   if delta>.003:changed+=1
 return {"changed":changed,"maximum_rgb_difference":maximum}
func share_world(node:Node,changed:Array)->void:
 if node is GeometryInstance3D and (node.layers&1)!=0 and node.get_instance_shader_parameter("source_local_active")==true:
  changed.append([node,node.layers]);node.layers|=2
 for child in node.get_children():share_world(child,changed)
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 RenderingServer.force_draw(false);game.flow_preview=false;var service=game.source_local_light_service;var data=game.source_local_light_data;var failures=[]
 game.camera.global_position=Vector3(-11,1.68,-23);game.camera.look_at(Vector3(5,.5,-21),Vector3.UP)
 await draw_game(game)
 if service.report.migrated<254:failures.append("too few migrated original surfaces")
 var migrated=service.report.duplicate();var images=[];var weapons=[]
 for enabled in [false,true]:
  service.radiance_enabled=enabled;await draw_game(game);images.append(game.post_pipeline.world_port.get_texture().get_image());weapons.append(game.view_port.get_texture().get_image());root.get_texture().get_image().save_png("res://evidence/local-direct-on.png" if enabled else "res://evidence/local-direct-off.png")
 var contribution=difference(images[0],images[1])
 if contribution.changed<20:failures.append("original local direct has no actual contribution")
 var weapon_contribution=difference(weapons[0],weapons[1])
 if weapon_contribution.changed<20:failures.append("weapon pass local direct has no actual contribution")
 var original=[]
 for light in data.lights:original.append(light.light_energy);light.light_energy=1000.0
 # Main resets key/pool fallback energies. Draw without Main after overriding.
 await process_frame;RenderingServer.force_draw(false)
 var native_energies=[]
 for light in data.lights:native_energies.append(light.light_energy)
 var duplicate=difference(images[1],game.post_pipeline.world_port.get_texture().get_image())
 if duplicate.maximum_rgb_difference>.001:failures.append("native direct duplicates migrated geometry")
 var duplicate_weapon=difference(weapons[1],game.view_port.get_texture().get_image())
 if duplicate_weapon.maximum_rgb_difference>.001:failures.append("native direct duplicates weapon pass")
 for index in data.lights.size():data.lights[index].light_energy=original[index]
 for index in data.lights.size():
  var expected=service.WORLD_FALLBACK|service.WEAPON_FALLBACK if index<10 else service.WEAPON_FALLBACK
  if data.lights[index].light_cull_mask!=expected:failures.append("native light mask "+str(index))
 service.enabled=false;await draw_game(game)
 for index in data.lights.size():
  if data.lights[index].light_cull_mask!=service.original_masks[index]:failures.append("fallback light mask restore "+str(index))
 service.enabled=true;await draw_game(game)
 var reentry=difference(images[1],game.post_pipeline.world_port.get_texture().get_image())
 if reentry.maximum_rgb_difference>.001:failures.append("source local reentry changed output")
 var shared=[];share_world(game,shared);var key_images=[];var key_weapons=[]
 for visible in [false,true]:
  game.view_key_light.visible=visible;await draw_game(game);key_images.append(game.post_pipeline.world_port.get_texture().get_image());key_weapons.append(game.view_port.get_texture().get_image())
 var shared_world=difference(key_images[0],key_images[1]);var shared_weapon=difference(key_weapons[0],key_weapons[1])
 if shared.is_empty() or shared_world.maximum_rgb_difference>.001 or shared_weapon.changed<20:failures.append("current camera mask selection on shared layer3 meshes")
 for entry in shared:entry[0].layers=entry[1]
 var report={"migrated":migrated,"contribution":contribution,"weapon_contribution":weapon_contribution,"native_energy_1000":duplicate,"native_weapon_energy_1000":duplicate_weapon,"draw_native_energies":native_energies,"reentry":reentry,"shared_layer3_objects":shared.size(),"shared_key_world":shared_world,"shared_key_weapon":shared_weapon,"failures":failures,"scope":"Actual source Main 254+ objects original point/key direct on/off HDR samples in world and weapon passes; native lights energy1000 set after Main with actual draw energies recorded; source/native fallback off/on masks and reentry. Shared world geometry layer3 key visibility toggle tests current camera mask selection. Numerical coupled BRDF fixture and full visual parity remain separate gates."}
 FileAccess.open("res://evidence/local-light-service-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
