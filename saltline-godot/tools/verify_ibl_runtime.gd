extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var all_standard="--all-standard" in OS.get_cmdline_user_args()
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{});game.camera.global_position=Vector3(-25,2.5,6);game.camera.look_at(Vector3(0,1.5,-8),Vector3.UP)
 var service=game.source_ibl_service;var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/environment-bindings.json"));var bindings={};var material_records={};var failures=[];var checked=0;var rooms=0;var objects=0;var viewmodels=0
 for binding in reference.bindings:bindings[binding.id]=binding
 for record in game.source_scene.source.materials:
  material_records[record.id]=record
  if record.type!="MeshStandardMaterial" or (not all_standard and record.name in ["apron_wet","sea","saltline_arm"]):continue
  var material=game.source_scene.materials[record.id];var expected=bindings[record.id].explicit_env!=null;checked+=1
  if expected:rooms+=1
  if material.get_shader_parameter("source_ibl_ready")!=true:failures.append("not ready "+record.id)
  if material.get_shader_parameter("source_ibl_explicit_room")!=expected:failures.append("wrong environment "+record.id)
  if record.name not in ["apron_wet","sea","saltline_arm"] and material.get_shader_parameter("has_ao_map")!=(record.props.get("aoMap")!=null):failures.append("wrong AO presence "+record.id)
 for id in game.source_scene.records:
  var record=game.source_scene.records[id]
  if not record.has("geometry"):continue
  var uses=false
  for material_id in record.materials:
   var m=material_records[material_id]
   if m.type=="MeshStandardMaterial" and (all_standard or m.name not in ["apron_wet","sea","saltline_arm"]):uses=true
  if not uses:continue
  var node=game.source_scene.source_nodes[id];var expected=(int(record.layers)&2)!=0;objects+=1
  if expected:viewmodels+=1
  if node.get_instance_shader_parameter("source_ibl_viewmodel")!=expected:failures.append("wrong view tag "+id)
 if checked!=(138 if all_standard else 135) or rooms!=22:failures.append("unexpected original material count")
 for entry in [[Vector3(0,-100,-20),true],[Vector3(-16,1,-20),false],[Vector3(12,1,-20),false],[Vector3(0,9.5,-20),false],[Vector3(0,1,-28),false],[Vector3(0,1,-11),false]]:
  if service.inside(entry[0])!=entry[1]:failures.append("interior boundary mismatch")
 var images=[]
 for enabled in [false,true]:
  service.radiance_enabled=enabled
  for warm in 12:game._process(0.0);await RenderingServer.frame_post_draw
  images.append(game.post_pipeline.scene_port.get_texture().get_image());root.get_texture().get_image().save_png("res://evidence/ibl-on.png" if enabled else "res://evidence/ibl-off.png")
 var changed=0;var maximum=0.0;var sum=0.0
 for y in range(0,images[0].get_height(),4):
  for x in range(0,images[0].get_width(),4):
   var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);sum+=delta;maximum=maxf(maximum,delta)
   if delta>.003:changed+=1
 if changed<20:failures.append("no actual IBL contribution")
 var report={"all_standard":all_standard,"materials":checked,"explicit_room_materials":rooms,"original_objects":objects,"viewmodels":viewmodels,"changed_hdr_samples":changed,"maximum_rgb_difference":maximum,"sum_rgb_difference":sum,"service":service.report.duplicate(),"failures":failures,"scope":("Actual source scene all138 Standard/254nodes including ground sea arms,environment/viewtag/AO-presence and strict boundary audit,off/on rawHDR contribution;not full image parity or local-direct replacement." if all_standard else "Actual source scene135 genericStandard/250nodes environment/viewtag/AO-presence and strict boundary audit,off/on rawHDR contribution;specialized shaders excluded from this audit.")};FileAccess.open("res://evidence/ibl-all-standard-runtime-verification.json" if all_standard else "res://evidence/ibl-runtime-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
