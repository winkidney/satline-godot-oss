extends "res://scripts/level_showcase_runner.gd"

var enemy_part="both"
var enemy_frozen=false
var prewarm:Variant=null
var enemy_start_time=0.0
var source_nav_tape=false
var nav_replay

func _initialize()->void:
 render_options=preload("res://scripts/studio_render_options.gd").new(OS.get_cmdline_user_args())
 capture="res://evidence/enemies-showcase.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--eshow="):enemy_part=arg.trim_prefix("--eshow=")
  elif arg.begins_with("--epre="):prewarm=float(arg.trim_prefix("--epre="))
  elif arg=="--efreeze":enemy_frozen=true
  elif arg=="--source-nav-tape":source_nav_tape=true
  elif arg=="--level-freeze":frozen=true
  elif arg.begins_with("--level-frames="):limit=int(arg.get_slice("=",1))
  elif arg.begins_with("--level-capture="):capture=arg.trim_prefix("--level-capture=")
 assert(enemy_part in ["both","gull","hound","fight","dead"],"Invalid original enemy selector")
 assert(prewarm==null or (is_finite(float(prewarm)) and float(prewarm)>=0),"Invalid enemy prewarm")
 call_deferred("setup")

func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/enemies-showcase-reference.json"))["fight-controlled" if source_nav_tape else enemy_part]
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 preload("res://scripts/weapon_studio_environment.gd").isolate(game)
 game.source_scene.source.modules.level.skylights=[];game.ground_queries.interiors=[];game.ground_queries.metal_rects.clear();game.navigation.rebuild()
 game.game_flow.state="showcase"
 game.mission.set_difficulty("standard");game.player.invulnerable=true
 var manager=game.enemy_manager;var coordinator=manager.coordinator
 coordinator.rng.seed=9001;coordinator.time=0;coordinator.tokens=0;coordinator.token_time=-9;coordinator.last_type="";coordinator.want_times={"gull":-9.0,"hound":-9.0};manager.next_id=1;manager.noise_cooldown=0;manager.player_speed=0
 # Original KD starts fresh rather than retaining the mission activation history.
 for kind in ["gull","hound"]:
  var records=game.source_scene.source.modules.enemies.debug["gulls" if kind=="gull" else "hounds"]
  for actor in manager.pools[kind]:
   var fresh=game._cold_enemy_record(actor.state,records)
   for key in fresh:
    if key in ["rig","lens"]:continue
    var value=fresh[key]
    actor.state[key]=Vector3(value[0],value[1],value[2]) if actor.state.get(key) is Vector3 and value is Array else value.duplicate(true) if value is Dictionary or value is Array else value
   if kind=="hound":
    for foot in actor.state.feet:
     for key in ["p","from","to","slide"]:
      var v=foot[key];foot[key]=Vector3(v[0],v[1],v[2])
   else:
    for i in 4:actor.flight.rotor_angles[i]=0.0
   if kind=="hound":actor.behavior.cover_points=[]
 if source_nav_tape:
  assert(enemy_part=="fight" and enemy_frozen,"Navigation replay requires frozen fight diagnostic")
  nav_replay=load("res://tools/enemy_showcase_nav_replay.gd").new(game.player.physics);nav_replay.tape=reference.enemies.nav_tape
  for actor in manager.pools.hound:actor.movement.navigation=nav_replay
 # KD prewarms before returning its showcase camera; ov camera begins at the origin.
 game.camera.position=Vector3.ZERO
 var duration={"both":2.6,"gull":1.2,"hound":1.25,"fight":7.0,"dead":.42}[enemy_part]
 match enemy_part:
  "gull":_spawn("gull",Vector3(0,1.6,0),{"passive":true,"hover":1.6,"patrolRadius":.02,"yaw":.7})
  "hound":_spawn("hound",Vector3.ZERO,{"passive":true,"yaw":.9,"patrolLine":[Vector3(1.6,0,1.3),Vector3(-1.6,0,-1.3)]})
  "fight":
   for position in [Vector3(-7,0,-9),Vector3(8,0,-7),Vector3(0,0,-14)]:_spawn("hound",position,{"state":"alert"})
   for position in [Vector3(-5,6,-13),Vector3(9,6,-11)]:_spawn("gull",position,{"state":"alert"})
  "dead":
   var hound=_spawn("hound",Vector3.ZERO,{"passive":true,"yaw":.8})
   var gull=_spawn("gull",Vector3(-1.6,3.4,-.5),{"passive":true,"hover":3.4,"patrolRadius":.02})
   _spawn("hound",Vector3(2.2,0,-1.6),{"passive":true,"yaw":-.6,"patrolLine":[Vector3(2.2,0,-1.6),Vector3(3.4,0,-3)]})
   for i in 30:manager.update(1.0/60)
   hound.damage(999,hound.state.pos,Vector3(.6,0,-.8),"body")
   for i in 110:manager.update(1.0/60)
   gull.damage(999,gull.state.pos,Vector3(0,0,1),"body")
  _:
   _spawn("gull",Vector3(-.9,2.2,-.2),{"passive":true,"hover":2.2,"patrolRadius":.25,"yaw":.5})
   _spawn("hound",Vector3(.2,0,.6),{"passive":true,"yaw":1.2,"patrolLine":[Vector3(2.6,0,1.2),Vector3(-1.8,0,.2)]})
 for i in int(floor(float(duration if prewarm==null else prewarm)*60+.5)):manager.update(1.0/60)
 enemy_start_time=coordinator.time;game.animation_time=0;game.source_scene.update_backdrop_time(0);game.rain_system.time=0
 view()
 # The original stepped bootstrap runs global FX/light decay before publishing ready.
 var remaining=float(reference.source_time)
 while remaining>1e-9:
  var step=minf(remaining,1.0/60)
  if not enemy_frozen:manager.update(step)
  game._advance_effects(step);game._process(step);remaining-=step
 preload("res://scripts/weapon_studio_environment.gd").after_frame(game)
 game.source_ibl_service.update(0)
 for material in level_materials:material.set_shader_parameter("source_ibl_explicit_room",false)
 ready=true
 if boot_loading!=null:await boot_loading.finish_showcase(game)

func _spawn(kind:String,position:Vector3,options:Dictionary)->Variant:
 var actor=game.enemy_manager.spawn(kind,position,options);assert(actor!=null,"Enemy pool exhausted")
 var group=game.source_scene.source_nodes[actor.state.rig.group["$node"]]
 preload("res://scripts/weapon_studio_environment.gd")._restore_visuals(group)
 _collect(group);return actor

func _collect(node:Node)->void:
 if node is GeometryInstance3D:
  level_nodes.append(node)
  for material in game.source_ibl_service._materials(node):
   if game.source_ibl_service._supported(material) and material not in level_materials:level_materials.append(material)
 for child in node.get_children():_collect(child)

func _process(dt:float)->bool:
 if not ready or finishing:return false
 frames+=1;view()
 var step=0.0 if frozen else minf(dt,.05)
 if not enemy_frozen:game.enemy_manager.update(step)
 game._advance_effects(step);game._process(step)
 preload("res://scripts/weapon_studio_environment.gd").after_frame(game);view()
 if Input.is_physical_key_pressed(KEY_ESCAPE) or (limit>0 and frames>=limit):finishing=true;call_deferred("finish")
 return false

func finish()->void:
 await process_frame;RenderingServer.force_draw(false)
 var failures=[];var actors=[];var maximum_position_error=0.0;var maximum_bone_error=0.0;var maximum_group_error=0.0;var maximum_world_error=0.0;var maximum_light_position_error=0.0;var maximum_light_energy_error=0.0;var maximum_light_color_error=0.0;var maximum_light_range_error=0.0
 var expected=reference.enemies.actors
 var controlled_pose=prewarm==null and enemy_frozen and (enemy_part!="fight" or source_nav_tape)
 if controlled_pose and game.enemy_manager.active.size()!=expected.size():failures.append("original active actor count")
 for index in game.enemy_manager.active.size():
  var actor=game.enemy_manager.active[index];var state=actor.state;var bone_matrices={};var world_matrices={}
  var group_matrix=_source_matrix(game.source_scene.source_nodes[state.rig.group["$node"]].transform)
  if controlled_pose and index<expected.size():
   for j in 16:maximum_group_error=maxf(maximum_group_error,absf(group_matrix[j]-float(expected[index].group[j])))
  for key in state.rig.bones:
   var t=game.source_scene.source_nodes[state.rig.bones[key]["$node"]].transform
   var matrix=_source_matrix(t)
   bone_matrices[key]=matrix
   world_matrices[key]=_source_matrix(game.source_scene.source_nodes[state.rig.bones[key]["$node"]].global_transform)
   if index<expected.size() and controlled_pose:
    for j in 16:
     maximum_bone_error=maxf(maximum_bone_error,absf(matrix[j]-float(expected[index].bones[key].matrix[j])))
     maximum_world_error=maxf(maximum_world_error,absf(world_matrices[key][j]-float(expected[index].bones[key].world[j])))
  if index<expected.size():
   var e=expected[index].state
   if controlled_pose and state.type!=e.type:failures.append("original actor type/order")
   if controlled_pose:
    if state.alive!=e.alive:failures.append("original death state")
    maximum_position_error=maxf(maximum_position_error,state.pos.distance_to(Vector3(e.pos[0],e.pos[1],e.pos[2])))
  actors.append({"type":state.type,"alive":state.alive,"pos":[state.pos.x,state.pos.y,state.pos.z],"phase":state.phase,"group":group_matrix,"world_bones":world_matrices,"bones":bone_matrices})
 if not enemy_frozen and not frozen and frames>1 and game.enemy_coordinator.time<=enemy_start_time:failures.append("live enemy clock")
 if controlled_pose and (maximum_position_error>.0001 or maximum_bone_error>.0001 or maximum_group_error>.0001 or maximum_world_error>.0001):failures.append("original controlled pose mismatch")
 if source_nav_tape:
  if nav_replay.cursor!=nav_replay.tape.size() or nav_replay.maximum_origin_error>.0001:failures.append("original navigation call sequence")
  failures.append_array(nav_replay.failures)
 if controlled_pose:
  if game.light_pool.slots.size()!=reference.pool_lights.size():failures.append("original pool light count")
  for index in mini(game.light_pool.slots.size(),reference.pool_lights.size()):
   var slot=game.light_pool.slots[index];var light=reference.pool_lights[index];var color=slot.light.light_color.srgb_to_linear()
   maximum_light_position_error=maxf(maximum_light_position_error,slot.light.global_position.distance_to(Vector3(light.position[0],light.position[1],light.position[2])))
   maximum_light_energy_error=maxf(maximum_light_energy_error,absf(float(slot.source_intensity)-float(light.intensity)))
   maximum_light_range_error=maxf(maximum_light_range_error,absf(slot.light.omni_range-float(light.distance)))
   for channel in 3:maximum_light_color_error=maxf(maximum_light_color_error,absf(color[channel]-float(light.color[channel])))
  if maximum_light_position_error>.0001 or maximum_light_energy_error>.000001 or maximum_light_color_error>.00001 or maximum_light_range_error>.00001:failures.append("original pool light state")
 if game.enemy_coordinator.tuning!=game.mission.rules.enemies:failures.append("original baseline enemy tuning")
 if game.player.health!=100 or not game.player.alive:failures.append("source stub player damage changed state")
 root.get_texture().get_image().save_png(capture)
 var report={"runner_sha256":FileAccess.get_sha256("res://scripts/enemies_showcase_runner.gd"),"reference_sha256":FileAccess.get_sha256("res://assets/export/enemies-showcase-reference.json"),"part":enemy_part,"frames":frames,"enemy_time":game.enemy_coordinator.time,"start_time":enemy_start_time,"enemy_frozen":enemy_frozen,"tuning":game.enemy_coordinator.tuning,"player":{"health":game.player.health,"alive":game.player.alive,"invulnerable":game.player.invulnerable},"world_frozen":frozen,"controlled_pose":controlled_pose,"nav_replay":{"enabled":source_nav_tape,"calls":nav_replay.cursor if source_nav_tape else 0,"maximum_origin_error":nav_replay.maximum_origin_error if source_nav_tape else 0},"maximum_light_errors":{"position":maximum_light_position_error,"intensity":maximum_light_energy_error,"color":maximum_light_color_error,"range":maximum_light_range_error} if controlled_pose else null,"pool_lights":game.light_pool.slots.map(func(slot):return {"position":[slot.light.global_position.x,slot.light.global_position.y,slot.light.global_position.z],"intensity":slot.source_intensity,"busy":slot.busy,"range":slot.light.omni_range,"color":[slot.light.light_color.srgb_to_linear().r,slot.light.light_color.srgb_to_linear().g,slot.light.light_color.srgb_to_linear().b]}),"scan_light":{"selected_id":game.enemy_manager.scan_light.selected_id,"samples":game.enemy_manager.scan_light.samples},"actors":actors,"maximum_position_error":maximum_position_error if controlled_pose else null,"maximum_group_matrix_error":maximum_group_error if controlled_pose else null,"maximum_world_bone_error":maximum_world_error if controlled_pose else null,"maximum_local_bone_error":maximum_bone_error if controlled_pose else null,"render_options":render_options.report(game),"failures":failures,"scope":"Original KD spawn/prewarm/death scenarios using existing native enemy actors. Controlled poses use1e-4 position/group/local/world-matrix limits and compare all6 pool lights; fight needs original nav-point replay because original Math.random is independent of eseed. This does not prove whole-image parity."}
 FileAccess.open(capture.trim_suffix(".png")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"part":enemy_part,"controlled_pose":controlled_pose,"maximum_position_error":maximum_position_error if controlled_pose else null,"maximum_group_matrix_error":maximum_group_error if controlled_pose else null,"maximum_world_bone_error":maximum_world_error if controlled_pose else null,"maximum_local_bone_error":maximum_bone_error if controlled_pose else null,"failures":failures}));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)

func _source_matrix(t:Transform3D)->Array:
 return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
