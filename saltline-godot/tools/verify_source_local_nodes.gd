extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{});game.flow_preview=false
 var failures=[];var lights=[];var records=[];var key_cases=[]
 if ProjectSettings.get_setting("rendering/lights_and_shadows/use_physical_light_units",false):failures.append("native fallback unit conversion requires default nonphysical units")
 for record in game.source_scene.source.nodes:
  if record.type!="PointLight" or game.source_scene.records.get(record.parent,{}).get("name","")!="level-dynamic":continue
  var node=game.source_scene.source_nodes[record.id]
  if not node is OmniLight3D:failures.append("missing source point "+record.id);continue
  var props=record.light;var matrix=record.matrixWorld;var position=Vector3(matrix[12],matrix[13],matrix[14]);var color=node.light_color.srgb_to_linear();var color_error=maxf(absf(color.r-props.color[0]),maxf(absf(color.g-props.color[1]),absf(color.b-props.color[2])))
  if node.global_position.distance_to(position)>.00001 or color_error>.000001 or absf(node.light_energy-float(props.intensity)/PI)>.00001 or node.omni_range!=props.distance or node.omni_attenuation!=props.decay or node.shadow_enabled!=record.castShadow:failures.append("source light mismatch "+record.id)
  lights.append(node);records.append({"id":record.id,"source_intensity":node.get_meta("source_intensity"),"native_energy":node.light_energy,"position_error":node.global_position.distance_to(position),"color_error":color_error})
 if lights.size()!=4:failures.append("expected4 warehouse lights")
 for entry in [[Vector3(-25,1.68,6),.9],[Vector3(0,1.68,-20),.495],[Vector3(0,-100,-20),.495],[Vector3(0,9.5,-20),.9]]:
  game.camera.global_position=entry[0];game.camera.look_at(entry[0]+Vector3(1,-.1,-1),Vector3.UP);game._process(0.0);var source_energy=float(game.view_key_light.get_meta("source_intensity"));var direction=game.camera.global_basis*Vector3(-.65,.85,1).normalized();var error=game.view_key_light.global_basis.z.distance_to(direction)
  key_cases.append({"source_intensity":source_energy,"expected":entry[1],"direction_error":error})
  if absf(source_energy-entry[1])>.000001 or absf(game.view_key_light.light_energy-entry[1]/PI)>.000001 or error>.000001:failures.append("view key source mismatch")
 game.camera.global_position=Vector3(-11,1.68,-23);game.camera.look_at(Vector3(5,.5,-21),Vector3.UP);var images=[]
 for enabled in [false,true]:
  for light in lights:light.set_meta("source_intensity",34.0 if enabled else 0.0);light.light_energy=34.0/PI if enabled else 0.0
  for warm in 12:game._process(0.0);await process_frame;RenderingServer.force_draw(false)
  images.append(game.post_pipeline.scene_port.get_texture().get_image());root.get_texture().get_image().save_png("res://evidence/warehouse-lights-on.png" if enabled else "res://evidence/warehouse-lights-off.png")
 var changed=0;var maximum=0.0;var sum=0.0
 for y in range(0,images[0].get_height(),4):
  for x in range(0,images[0].get_width(),4):
   var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta);sum+=delta
   if delta>.003:changed+=1
 if changed<20:failures.append("warehouse point lights do not contribute")
 var report={"static_lights":records,"key_cases":key_cases,"changed_hdr_samples":changed,"maximum_rgb_difference":maximum,"sum_rgb_difference":sum,"failures":failures,"scope":"Actual4 sourcewarehouse Omni nodes original transforms/color/intensity/range/decay/shadow flags,sourceunits storedseparately andnativefallback /PI;viewkey indoor .55 anddirection audit;source point contribution off/on. Numerical original BRDF parity and pool timing have separate tests."};FileAccess.open("res://evidence/source-local-nodes-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
