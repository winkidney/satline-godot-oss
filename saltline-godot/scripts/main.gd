extends Node3D
signal initialization_complete
var boot_overlay

var source_scene:SaltlineSourceScene
var camera:Camera3D
var showcase_render=false
var velocity:=Vector3.ZERO
var status:Label
var post_pipeline:SaltlinePostPipeline
var planar_preview=false
var planar_reports=[]
var planar_images=[]
var planar_trace
var planar_reflection
var render_quality
var source_sun_service
var source_local_light_data
var source_local_light_service
var source_ibl_service
var view_key_light:DirectionalLight3D
var world_sun:DirectionalLight3D
var sun_shadow_pass:SaltlineSunShadowPass
var sky_weather:SaltlineSkyWeather
var sky_preview=false
var sky_frame=0
var sky_reports=[]
var sky_thunder_events=[]
var rain_system:SaltlineRain
var rain_preview=false
var rain_frame=0
var rain_reports=[]
var sea_preview=false
var sea_frame=0
var capture_mode:=false
var preview_mode:=false
var preview_frame:=0
var preview_start:Transform3D
var player:SaltlinePlayer
var jump_pending=false
var animation_time=0.0
var timed_materials:Array[ShaderMaterial]=[]
var weapon:SaltlineWeapon
var weapon_animation:SaltlineWeaponAnimation
var weapon_actions:Dictionary={}
var source_gamepad_input=preload("res://scripts/source_gamepad_input.gd").new()
var source_touch_input=preload("res://scripts/source_touch_input.gd").new()
var touch_overlay
var touch_buttons={}
var source_mouse_buttons={}
var touch_last_start_ms=-1000
var gamepad_device=preload("res://scripts/gamepad_device.gd").new()
var input_device="kbm"
var rumble_requests=[]
var source_keyboard_input=preload("res://scripts/source_keyboard_input.gd").new()
var source_mouse_input=preload("res://scripts/source_mouse_input.gd").new()
var ammo_label:Label
var last_impact:Dictionary={}
var view_camera:Camera3D
var view_port:SubViewport
var weapon_preview=false
var weapon_preview_frame=0
var weapon_effects:SaltlineWeaponEffects
var shells:SaltlineShells
var tracers:SaltlineTracers
var decals:SaltlineDecals
var impact_effects:SaltlineImpactEffects
var ground_queries
var light_pool:SaltlineLightPool
var explosion_effects:SaltlineExplosionEffects
var explosion_preview=false
var explosion_frame=0
var explosives:SaltlineExplosives
var barrel_preview=false
var barrel_frame=0
var barrel_hidden_slots=0
var barrel_blast_count=0
var navigation:SaltlineNavigation
var player_min_health=100.0
var player_damage_events=[]
var game_mode=false
var sight_preview=false
var sight_reports=[]
var source_sun_preview=false
var source_sun_reports=[]
var source_sun_images=[]
var motion_preview=false
var motion_reports=[]
var volume_preview=false
var volume_reports=[]
var volume_images=[]
var ao_preview=false
var ao_reports=[]
var solar_preview=false
var solar_reports=[]
var post_preview=false
var status_preview=false
var status_reports=[]
var feedback_preview=false
var feedback_actor:SaltlineHoundActor
var feedback_reports=[]
var feedback_shots=[]
var navigation_preview=false
var navigation_reports=[]
var flow_preview=false
var flow_preview_frame=0
var game_flow:SaltlineGameFlow
var game_ui:SaltlineGameUI
var original_audio:Node
var session:SaltlineSession
var pause_pending=false
var flow_clock_samples=[]
var flow_history=[]
var reset_reports=[]
var radio_reports=[]
var pause_snapshot:Dictionary={}
var pause_unchanged=false
var mission:SaltlineMission
var relay_visuals:SaltlineRelays
var mission_preview=false
var mission_preview_frame=0
var mission_label:Label
var mission_prompt=""
var mission_progress=0.0
var mission_events=[]
var gull_preview=false
var gull_preview_frame=0
var gull_actor:SaltlineGullActor
var gull_bolt_requests=0
var gull_crashes=0
var enemy_manager:SaltlineEnemyManager
var enemy_pool_preview=false
var enemy_pool_frame=0
var pool_preview_actors=[]
var pool_preview_reused_id=0
var source_bootstrap
var fx_random
var combat:SaltlineCombat
var enemy_coordinator:SaltlineEnemyCoordinator
var hound_preview=false
var hound_frame=0
var hound_pose:SaltlineHoundPose
var hound_route_preview=false
var hound_combat_preview=false
var hound_fight=false
var hound_actor_preview=false
var hound_actor:SaltlineHoundActor
var hound_actor_frame=0
var hound_actor_player_hits=0
var hound_locomotion:SaltlineHoundLocomotion

func _ready()->void:
 var args=OS.get_cmdline_user_args();planar_preview="--planar-preview" in args;source_sun_preview="--source-sun-preview" in args;motion_preview="--motion-preview" in args;volume_preview="--volume-preview" in args;ao_preview="--ao-preview" in args;solar_preview="--solar-preview" in args;sight_preview="--sight-preview" in args;post_preview="--post-preview" in args;status_preview="--status-preview" in args or post_preview;feedback_preview="--feedback-preview" in args;navigation_preview="--navigation-preview" in args;game_mode=args.is_empty() or "--game" in args or "--flow-preview" in args or navigation_preview or feedback_preview or status_preview or sight_preview or solar_preview or ao_preview or volume_preview or motion_preview or source_sun_preview or planar_preview;flow_preview="--flow-preview" in args or navigation_preview or feedback_preview or status_preview or sight_preview or solar_preview or ao_preview or volume_preview or motion_preview or source_sun_preview or planar_preview
 sky_preview="--sky-preview" in args
 rain_preview="--rain-preview" in args
 sea_preview="--sea-preview" in args
 capture_mode="--capture" in OS.get_cmdline_user_args()
 source_scene=SaltlineSourceScene.new();add_child(source_scene)
 if boot_overlay!=null:await source_scene.load_source(boot_overlay.stage)
 else:source_scene.load_source()
 camera=source_scene.camera
 if boot_overlay!=null:await boot_overlay.stage("Flooding the apron",.58)
 source_bootstrap=preload("res://scripts/source_bootstrap.gd").new()
 fx_random=preload("res://scripts/fx_random.gd").new()
 preview_mode="--preview" in OS.get_cmdline_user_args()
 preview_start=camera.transform
 _environment();_interface()
 player=SaltlinePlayer.new(source_scene.source.modules.player,SaltlinePhysics.new(source_scene.source.physics))
 ground_queries=preload("res://scripts/ground_queries.gd").new(source_scene.source)
 player.surface_resolver=ground_queries.resolve_player_surface
 player.hit.connect(_player_hit)
 navigation=SaltlineNavigation.new(player.physics,fx_random)
 enemy_coordinator=SaltlineEnemyCoordinator.new(source_scene.source.modules.enemies.TUNE,player.physics,player)
 combat=SaltlineCombat.new(player.physics,player)
 combat.impact.connect(_combat_impact)
 _collision()
 animation_time=0.0 if game_mode else source_scene.source.time.t
 source_scene.update_backdrop_time(animation_time)
 for record in source_scene.source.materials:
  if record.get("patch",{}).get("uniforms",{}).has("uTime") and source_scene.materials[record.id] is ShaderMaterial:
   timed_materials.append(source_scene.materials[record.id])
 if boot_overlay!=null:await boot_overlay.stage("Loading tracers and smoke",.66)
 weapon=SaltlineWeapon.new(source_scene.source.modules.weapon,{},-1,source_bootstrap.streams.weapon)
 player.motion_event.connect(weapon.on_player_motion_event)
 weapon_animation=SaltlineWeaponAnimation.new(source_scene)
 weapon.bind_presentation(weapon_animation)
 weapon_animation.parts_view=preload("res://scripts/weapon_parts_view.gd").new(source_scene,weapon.parts_motion,weapon.magazine_motion)
 weapon.fired.connect(_weapon_fired)
 _viewmodel_pass()
 weapon_animation.drop_view=preload("res://scripts/weapon_drop_view.gd").new(source_scene,camera,view_camera,weapon.motion_randf)
 light_pool=SaltlineLightPool.new();add_child(light_pool)
 if game_mode:
  source_local_light_data=preload("res://scripts/source_local_light_data.gd").new();source_local_light_data.setup(source_scene,light_pool,view_key_light)
  source_local_light_service=preload("res://scripts/source_local_light_service.gd").new();source_local_light_service.setup(self,source_scene,source_local_light_data)
 weapon_effects=SaltlineWeaponEffects.new();add_child(weapon_effects);weapon_effects.setup(source_scene,camera,weapon,light_pool)
 shells=SaltlineShells.new(source_scene,player.physics,fx_random)
 tracers=SaltlineTracers.new();add_child(tracers);tracers.setup(source_scene,camera,false,fx_random)
 decals=SaltlineDecals.new(source_scene,fx_random)
 impact_effects=SaltlineImpactEffects.new();add_child(impact_effects);impact_effects.setup(source_scene,camera,player.physics,fx_random);impact_effects.light_pool=light_pool;impact_effects.ground_queries=ground_queries;impact_effects.tracer_pool=tracers
 weapon.smoke_requested.connect(_weapon_smoke_requested)
 player.motion_event.connect(_player_motion_effects)
 if boot_overlay!=null:await boot_overlay.stage("Checking the rifle",.74)
 enemy_manager=SaltlineEnemyManager.new(enemy_coordinator,combat)
 enemy_manager.bolts=SaltlineBolts.new(enemy_coordinator.tuning,player.physics,player);enemy_manager.bolts.setup(source_scene)
 enemy_manager.bolts.impact.connect(_combat_impact)
 enemy_manager.scan_light=SaltlineGullScanLight.new(player.physics,light_pool);enemy_manager.camera=camera
 var covers=[]
 for point in source_scene.source.modules.level.coverPoints:covers.append(Vector3(point[0],point[1],point[2]))
 if boot_overlay!=null:await boot_overlay.stage("Waking the Harbormaster",.82)
 for record in source_scene.source.modules.enemies.debug.gulls:
  var actor=SaltlineGullActor.new(source_scene,_cold_enemy_record(record,source_scene.source.modules.enemies.debug.gulls),enemy_coordinator,impact_effects)
  actor.bolt_requested.connect(_gull_bolt_request);actor.explosion_requested.connect(_gull_explosion);actor.blast_effect.connect(_gull_blast_effect)
  enemy_manager.add_to_pool("gull",actor)
 for record in source_scene.source.modules.enemies.debug.hounds:
  var actor=SaltlineHoundActor.new(source_scene,_cold_enemy_record(record,source_scene.source.modules.enemies.debug.hounds),navigation,enemy_coordinator,impact_effects,covers)
  actor.shot.connect(_hound_actor_shot);actor.melee.connect(func(amount,position):player.damage(amount,position))
  enemy_manager.add_to_pool("hound",actor)
 gull_preview="--gull-preview" in OS.get_cmdline_user_args()
 if gull_preview:
  player.pos=Vector3(-24,0,6);player.eye=player.pos+Vector3(0,1.68,0)
  gull_actor=enemy_manager.spawn("gull",Vector3(-30,4,6),{"hover":4,"yaw":PI/2,"patrolRadius":2})
  camera.global_position=gull_actor.state.pos+Vector3(3,1.4,4);camera.look_at(gull_actor.state.pos,Vector3.UP);view_camera.cull_mask=0
 enemy_pool_preview="--enemy-pool-preview" in OS.get_cmdline_user_args()
 if enemy_pool_preview:
  player.pos=Vector3(-26,0,10);player.eye=player.pos+Vector3(0,1.68,0)
  for i in 8:pool_preview_actors.append(enemy_manager.spawn("hound",Vector3(-32+(i%4)*2,0,3+int(i/4)*3),{"yaw":0,"passive":true,"patrolRadius":.1}))
  camera.global_position=Vector3(-27,4.3,12);camera.look_at(Vector3(-28,0,5),Vector3.UP)
 hound_combat_preview="--hound-combat-preview" in OS.get_cmdline_user_args()
 hound_fight="--hound-fight" in OS.get_cmdline_user_args()
 hound_actor_preview="--hound-actor-preview" in OS.get_cmdline_user_args() or hound_combat_preview
 if hound_actor_preview or hound_fight:
  player.pos=Vector3(-24,0,6);player.eye=player.pos+Vector3(0,1.68,0)
  hound_actor=enemy_manager.spawn("hound",Vector3(-32,0,6),{"yaw":PI/2,"state":"alert","target":player.pos})
  hound_actor.state.mode="engage"
  camera.global_position=Vector3(-28,2.2,11);camera.look_at(hound_actor.state.pos+Vector3(0,.6,0),Vector3.UP)
  if hound_combat_preview or hound_fight:
   camera.global_position=player.eye;camera.look_at(hound_actor.state.headPos,Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x
 hound_route_preview="--hound-route-preview" in OS.get_cmdline_user_args()
 hound_preview="--hound-preview" in OS.get_cmdline_user_args() or hound_route_preview
 if hound_preview:
  hound_pose=SaltlineHoundPose.new(source_scene,source_scene.source.modules.enemies.debug.hounds[0],player.physics)
  hound_pose.state.phase=.37;hound_pose.state.tyaw=.2;hound_pose.state.tpitch=-.05;hound_pose.state.hpitch=.1;hound_pose.state.hyaw=-.3
  hound_pose.reset(Vector3(-30,0,6),PI/2)
  if hound_route_preview:
   hound_pose.reset(Vector3(-32,0,6),0);hound_pose.state.mode="patrol"
   hound_locomotion=SaltlineHoundLocomotion.new(hound_pose.state,navigation,source_scene.source.modules.enemies.TUNE.hound,enemy_coordinator.rng)
   hound_locomotion.set_goal(Vector3(-24,0,6),true)
  camera.global_position=Vector3(-27,1.8,10);camera.look_at(hound_pose.state.pos+Vector3(0,.6,0),Vector3.UP)
 explosion_effects=SaltlineExplosionEffects.new(impact_effects,decals,light_pool,fx_random)
 explosives=SaltlineExplosives.new(source_scene,player.physics,explosion_effects,player,source_bootstrap.streams.explosives)
 explosives.combat=combat
 explosion_effects.exploded.connect(func(position,_size):enemy_manager.explosion(position))
 relay_visuals=SaltlineRelays.new(source_scene)
 mission_preview="--mission-preview" in OS.get_cmdline_user_args()
 if not game_mode and (mission_preview or "--mission" in OS.get_cmdline_user_args() or "--holdout" in OS.get_cmdline_user_args()):
  mission=SaltlineMission.new(source_scene.source.modules.level,enemy_manager,player,navigation,source_bootstrap.root)
  mission.relay_changed.connect(relay_visuals.set_state)
  mission.prompt_changed.connect(func(text,value):mission_prompt="" if text==null else str(text);mission_progress=value)
  mission.objective_done.connect(func(id,index,total):mission_events.append({"id":id,"index":index,"total":total,"frame":mission_preview_frame}))
  mission.resupply.connect(_mission_resupply)
  var layer=CanvasLayer.new();layer.layer=4;add_child(layer);mission_label=Label.new();mission_label.position=Vector2(16,110);layer.add_child(mission_label)
  mission.begin("holdout" if "--holdout" in OS.get_cmdline_user_args() else "mission")
  if mission_preview:player.invulnerable=true
 barrel_preview="--barrel-preview" in OS.get_cmdline_user_args()
 if barrel_preview:
  player.pos=Vector3(-24,0,6.2);player.safe_pos=player.pos;camera.global_position=player.pos+Vector3(0,1.68,0)
  camera.look_at(explosives.items[6].pos,Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x
 explosion_preview="--explosion-preview" in OS.get_cmdline_user_args()
 if explosion_preview:
  player.pos=Vector3(-26,0,6);player.safe_pos=player.pos;player.yaw=-PI/2
  camera.transform=Transform3D(Basis(Vector3.UP,-PI/2),player.pos+Vector3(0,1.68,0))
 if "--near-impact-preview" in OS.get_cmdline_user_args():
  player.pos=Vector3(-20,0,-1.3);player.safe_pos=player.pos;player.yaw=0;player.pitch=0
  camera.transform=Transform3D(Basis.IDENTITY,player.pos+Vector3(0,1.68,0))
 if "--tracer-probe" in OS.get_cmdline_user_args():
  tracers.emit(camera.global_transform*Vector3(-1,.4,-4),camera.global_transform*Vector3(1,.4,-4));tracers.update(1.0/60)
 if "--splash-probe" in OS.get_cmdline_user_args():
  camera.global_position=Vector3(-30,1.4,6);camera.look_at(Vector3(-27,0,6),Vector3.UP)
  impact_effects.splash(Vector3(-27,0,6),1.5)
  for i in 8:impact_effects.update(1.0/60)
 if "--debris-probe" in OS.get_cmdline_user_args():
  for i in 3:
   var colors=[Vector3(.8,.12,.06),Vector3(.08,.6,.15),Vector3(.08,.2,.9)]
   impact_effects.debris.emit(camera.global_transform*Vector3((i-1)*.7,.3,-3),Vector3.ZERO,Vector3(.3,.6,.2),colors[i],5,0)
  impact_effects.debris.update(1.0/60)
 if "--impact-probe" in OS.get_cmdline_user_args():
  var forward=Vector3.FORWARD
  var hit=player.physics.raycast(Vector3(-20,1.68,0),forward,300)
  if not hit.is_empty():
   camera.global_position=hit.point-forward*2.5
   camera.look_at(hit.point,Vector3.UP)
   for i in 7:
    var direction=(forward+camera.global_basis.x*((i%3)-1)*.045+Vector3.UP*((i/3)-1)*.045).normalized()
    decals.impact(player.physics.raycast(camera.global_position,direction,20))
   impact_effects.impact(hit,forward)
   for i in 4:impact_effects.update(1.0/60)
   print("IMPACT_PROBE "+str({"surface":hit.surface,"position":hit.point,"decals":decals.emitted}))
 if "--flash-probe" in OS.get_cmdline_user_args():
  weapon_effects.fire("rifle",weapon.rigs.rifle.def);weapon_effects.update(.001)
 weapon_preview="--weapon-preview" in OS.get_cmdline_user_args()
 if game_mode:_setup_game()
 print("SOURCE_SCENE_LOADED "+JSON.stringify(source_scene.report))
 sky_weather=SaltlineSkyWeather.new(source_scene.materials["0c4ecf1e-8376-473f-bfdc-ec19ecc5a41c"],fx_random)
 var rain_initial={}
 if not game_mode:
  rain_initial=source_bootstrap.bootstrap_data.streams.rain.initial_state.duplicate(true)
  rain_initial.time=animation_time;rain_initial.thunder_timer-=animation_time
 rain_system=SaltlineRain.new(source_scene,source_bootstrap.streams.rain,rain_initial);rain_system.thunder.connect(sky_weather.trigger)
 if original_audio!=null:original_audio.attach_weather(rain_system)
 rain_system.thunder.connect(func(intensity):sky_thunder_events.append({"frame":sky_frame,"intensity":intensity}))
 if sea_preview or rain_preview or sky_preview:view_camera.cull_mask=0;status.visible=false;ammo_label.visible=false
 if capture_mode:_capture()
 initialization_complete.emit()
 for arg in args:
  if arg.begins_with("--record-plan="):
   var recorder=load("res://tools/record_capture.gd").new();add_child(recorder);recorder.start(self,arg.trim_prefix("--record-plan="))

func _environment()->void:
 var world=WorldEnvironment.new();var env=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color(.20,.25,.32)
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(.44,.52,.63);env.ambient_light_energy=.65
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=.7
 env.ssao_enabled=not game_mode;env.ssao_radius=.9;env.ssao_intensity=1.6
 env.glow_enabled=true;env.glow_intensity=.12
 if game_mode:env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.tonemap_exposure=1;env.glow_enabled=false
 var info:Dictionary=source_scene.source.get("environment",{})
 if not info.is_empty():
  var image=Image.create_from_data(int(info.width),int(info.height),false,Image.FORMAT_RGBAF,FileAccess.get_file_as_bytes("res://assets/export/"+info.background));image.flip_y()
  var lighting=Image.create_from_data(int(info.width),int(info.height),false,Image.FORMAT_RGBAF,FileAccess.get_file_as_bytes("res://assets/export/"+info.lighting));lighting.flip_y()
  var panorama=ShaderMaterial.new();panorama.shader=load("res://shaders/source_panorama.gdshader");panorama.set_shader_parameter("background_panorama",ImageTexture.create_from_image(image));panorama.set_shader_parameter("lighting_panorama",ImageTexture.create_from_image(lighting))
  var sky=Sky.new();sky.sky_material=panorama;sky.radiance_size=Sky.RADIANCE_SIZE_256;env.sky=sky;env.background_mode=Environment.BG_SKY;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 world.environment=env;add_child(world)
 var sun=DirectionalLight3D.new();sun.light_color=Color(1,.72,.42).linear_to_srgb();sun.light_energy=3.0;sun.shadow_enabled=true;sun.directional_shadow_max_distance=150;sun.light_angular_distance=1.0
 world_sun=sun;add_child(sun);sun.look_at(-Vector3(.916,.225,.331),Vector3.UP)

func _collision()->void:
 for box in player.physics.boxes:
  if box.get("bulletOnly",false):continue
  var lo:Vector3=box.min;var hi:Vector3=box.max
  var body=StaticBody3D.new();var shape=CollisionShape3D.new();var bounds=BoxShape3D.new();bounds.size=(hi-lo).max(Vector3.ONE*.001);shape.shape=bounds;body.position=(hi+lo)*.5;body.add_child(shape);add_child(body)
  box.body=body

func _interface()->void:
 var layer=CanvasLayer.new();add_child(layer);status=Label.new();status.position=Vector2(16,16);status.add_theme_font_size_override("font_size",16)
 status.text="SALTLINE / Native Godot work in progress\nWASD move · Shift sprint · Ctrl crouch · Space jump · RMB aim\nLMB fire · R reload · 1/2 or Q switch · Esc release · F12 capture"
 layer.add_child(status)
 layer.layer=2
 ammo_label=Label.new();ammo_label.position=Vector2(1000,640);ammo_label.add_theme_font_size_override("font_size",22);layer.add_child(ammo_label)

func _viewmodel_pass()->void:
 if game_mode:
  planar_reflection=preload("res://scripts/planar_reflection.gd").new()
  if str(Engine.get_version_info().status).contains("saltline_oblique") or "--planar-experiment" in OS.get_cmdline_user_args() or planar_preview:planar_reflection.setup(self,source_scene,camera)
  sun_shadow_pass=SaltlineSunShadowPass.new();sun_shadow_pass.setup(self,source_scene)
  planar_reflection.order_before_sun(sun_shadow_pass.viewport)
  source_sun_service=preload("res://scripts/source_sun_service.gd").new();source_sun_service.setup(self,source_scene,sun_shadow_pass,world_sun)
  source_ibl_service=preload("res://scripts/source_ibl_service.gd").new();source_ibl_service.setup(self,source_scene,camera)
  post_pipeline=SaltlinePostPipeline.new();post_pipeline.sun_shadow=sun_shadow_pass;post_pipeline.setup_world(self,camera)
 camera.cull_mask=5 if game_mode else 1
 view_port=SubViewport.new();view_port.size=get_viewport().get_visible_rect().size;view_port.transparent_bg=true
 view_port.world_3d=get_world_3d();view_port.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view_port.msaa_3d=get_viewport().msaa_3d;add_child(view_port)
 view_camera=Camera3D.new();view_camera.fov=54;view_camera.near=.01;view_camera.far=10;view_camera.cull_mask=2;view_camera.keep_aspect=Camera3D.KEEP_HEIGHT
 var environment=get_world_3d().environment.duplicate();environment.background_mode=Environment.BG_CLEAR_COLOR;view_camera.environment=environment
 var key=DirectionalLight3D.new();view_key_light=key;key.name="viewmodel-key";key.set_meta("source_light_role","view-key");key.light_color=Color(.78,.86,1).linear_to_srgb();key.set_meta("source_intensity",.9);key.light_energy=.9/PI;key.light_cull_mask=2;key.shadow_enabled=false
 camera.add_child(key);key.basis=Basis.looking_at(Vector3(.65,-.85,-1),Vector3.UP)
 view_port.add_child(view_camera);view_camera.current=true
 var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
 var display=TextureRect.new();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.texture=view_port.get_texture();display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(display)
 if game_mode:
  post_pipeline.setup(view_port);post_pipeline.sun_direction=source_scene.materials["0c4ecf1e-8376-473f-bfdc-ec19ecc5a41c"].get_shader_parameter("uSunDir");post_pipeline.volume_sun_color=source_scene.materials["0c4ecf1e-8376-473f-bfdc-ec19ecc5a41c"].get_shader_parameter("uSunCol");post_pipeline.material.set_shader_parameter("uSunCol",post_pipeline.volume_sun_color);display.texture=post_pipeline.ldr_port.get_texture();display.material=post_pipeline.final_material
 else:
  var composite=ShaderMaterial.new();composite.shader=load("res://shaders/viewmodel_composite.gdshader");display.material=composite
 get_viewport().size_changed.connect(func():view_port.size=post_pipeline.render_size() if post_pipeline!=null else Vector2i(get_viewport().get_visible_rect().size))

func _input(event:InputEvent)->void:
 if game_mode and event is InputEventMouseButton and not event.pressed:source_mouse_buttons.erase(event.button_index)
 if game_mode and game_ui!=null and (event is InputEventScreenTouch or event is InputEventScreenDrag):
  if _touch_event(event):get_viewport().set_input_as_handled()
  return
 if game_mode and (event is InputEventJoypadButton or event is InputEventJoypadMotion):get_viewport().set_input_as_handled();return
 if game_mode and event is InputEventKey and not event.pressed:
  source_keyboard_input.key(event.physical_keycode if event.physical_keycode!=0 else event.keycode,false)

func _notification(what:int)->void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  source_keyboard_input.clear();source_gamepad_input.clear_gameplay();source_mouse_input.clear();source_touch_input.clear();touch_buttons.clear();source_mouse_buttons.clear()
  jump_pending=false;pause_pending=false;weapon_actions.clear()
  if game_mode and game_flow!=null and is_inside_tree() and game_flow.state in ["intro","playing"]:game_flow.pause()

func _unhandled_input(event:InputEvent)->void:
 if game_mode:
  _game_input_event(event);return
 if event is InputEventMouseButton and event.pressed:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
  player.look(event.relative)
 if event is InputEventKey and event.pressed:
  if event.keycode==KEY_ESCAPE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  if event.keycode==KEY_F12:_capture(false)
  if event.keycode==KEY_SPACE and not event.echo:jump_pending=true
  if not event.echo:
   if event.keycode==KEY_R:weapon_actions.reload=true
   if event.keycode==KEY_1:weapon_actions.weapon1=true
   if event.keycode==KEY_2:weapon_actions.weapon2=true
   if event.keycode==KEY_Q:weapon_actions.swap=true

func _process(dt:float)->void:
 if not game_mode:source_scene.update_sight_environment()
 if game_mode:
  var step=0.0 if ao_preview or volume_preview or source_sun_preview or planar_preview else 1.0/60 if flow_preview else minf(dt,.05)
  if flow_preview:_flow_preview_step(step)
  if game_flow.state!="title":source_scene.update_sight_environment()
  animation_time+=step
  if game_flow.state!="paused":
   source_scene.advance_backdrop(step)
   relay_visuals.update(step)
   _update_rain(step)
   for material in timed_materials:material.set_shader_parameter("uTime",rain_system.time)
  sky_weather.update(step,animation_time)
  game_ui.update_frame(step,animation_time);view_camera.global_transform=camera.global_transform
  if render_quality!=null:render_quality.frame(self)
  if source_sun_service!=null:source_sun_service.update()
  if source_ibl_service!=null:
   source_ibl_service.update(step)
   source_scene.update_weapon_wetness(step,source_ibl_service.view_room)
   if view_key_light!=null:
    var source_key_energy=.9*(.55 if source_ibl_service.view_room else 1.0);view_key_light.set_meta("source_intensity",source_key_energy);view_key_light.light_energy=source_key_energy/PI
  light_pool.update(minf(step,.05))
  if source_local_light_data!=null:source_local_light_data.update()
  if source_local_light_service!=null:source_local_light_service.update()
  if planar_reflection!=null:
   if post_pipeline!=null:planar_reflection.render_size=post_pipeline.world_port.size
   planar_reflection.update(camera)
  if sun_shadow_pass!=null:sun_shadow_pass.update()
  post_pipeline.tick(step,showcase_render,sky_weather.value)
  return
 if view_camera:view_camera.global_transform=camera.global_transform
 if not capture_mode:
  _update_rain(1.0/60 if sky_preview or rain_preview or sea_preview else 1.0/30 if preview_mode else dt)
  animation_time+=1.0/60 if sky_preview or rain_preview or sea_preview else 1.0/30 if preview_mode else dt
  for material in timed_materials:material.set_shader_parameter("uTime",animation_time)
  sky_weather.update(1.0/60 if sky_preview or rain_preview or sea_preview else dt,animation_time)
 if sky_preview:_sky_preview_step();return
 if rain_preview:_rain_preview_step();return
 if sea_preview:_sea_preview_step();return
 if relay_visuals and not mission_preview:relay_visuals.update(dt)
 if mission_preview:
  mission_preview_frame+=1
  var frame=mission_preview_frame
  if frame in [1,221,441]:
   var index=int((frame-1)/220);var relay:Dictionary=mission.relays[index]
   player.pos=relay.o.pos+Vector3(0,0,1.8);player.safe_pos=player.pos;player.eye=player.pos+Vector3(0,1.68,0);player.velocity=Vector3.ZERO
   camera.global_position=player.eye;camera.look_at(relay.o.pos+Vector3(0,1.2,0),Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x;player.forward=(relay.o.pos-player.pos).normalized()
  if frame==681:
   player.pos=mission.extraction.pos;player.safe_pos=player.pos;player.eye=player.pos+Vector3(0,1.68,0);player.velocity=Vector3.ZERO
  mission.update(1.0/60,frame<660)
  var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":false,"fire":false,"jump":false,"ads_value":weapon.ads}
  player.update(1.0/60,input,camera);_advance_weapon(1.0/60,input);relay_visuals.update(1.0/60);_mission_hud();view_camera.global_transform=camera.global_transform
  if frame in [90,170,390,610,740]:_mission_still(frame)
  if frame>=780:
   var report={"frames":frame,"state":mission.state,"cut":mission.run.cut,"relays":mission.relays.size(),"events":mission_events,"debrief":mission.debrief,"active_enemies":enemy_manager.active.size(),"alive_enemies":enemy_manager.alive_count(),"queue":mission.run.queue.size(),"gull_bolts":enemy_manager.bolts.emitted,"muzzle_flashes":impact_effects.enemy_muzzle_flashes,"relay_door_angles":[],"scope":"native mission relay interactions, real waves/enemies, extraction and relay animation; automated teleport/hold input and invulnerability, full original UI/intro/reset still pending"}
   for item in relay_visuals.items.values():report.relay_door_angles.append(item.animation.hinge)
   var file=FileAccess.open("res://evidence/mission-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
  return
 if gull_preview:
  gull_preview_frame+=1
  if gull_preview_frame==120:gull_actor.state.mode="engage"
  if gull_preview_frame==360:
   combat.player_shot(gull_actor.state.pos+Vector3(0,.4,0),Vector3.DOWN,100,1)
  enemy_manager.update(1.0/60);explosion_effects.update(1.0/60);impact_effects.update(1.0/60);light_pool.update(1.0/60)
  var offset=Vector3(3,1.4,4);var obstruction=player.physics.raycast(gull_actor.state.pos,offset.normalized(),offset.length())
  if not obstruction.is_empty():offset=offset.normalized()*maxf(.8,obstruction.dist-.25)
  camera.global_position=gull_actor.state.pos+offset;camera.look_at(gull_actor.state.pos,Vector3.UP);view_camera.global_transform=camera.global_transform
  if gull_preview_frame in [90,240,360,400,590]:_gull_still(gull_preview_frame)
  if gull_preview_frame>=600:
   var report={"frames":gull_preview_frame,"pool_gulls":enemy_manager.pools.gull.size(),"pool_hounds":enemy_manager.pools.hound.size(),"active":enemy_manager.active.size(),"alive":enemy_manager.alive_count(),"bolt_requests":gull_bolt_requests,"bolts_emitted":enemy_manager.bolts.emitted,"enemy_muzzle_flashes":impact_effects.enemy_muzzle_flashes,"bolt_hits":enemy_manager.bolts.player_hits,"bolt_world_hits":enemy_manager.bolts.world_hits,"max_visible_bolts":enemy_manager.bolts.maximum_live,"scan_energy":enemy_manager.scan_light.energy,"max_scan_energy":enemy_manager.scan_light.maximum_energy,"scan_samples":enemy_manager.scan_light.samples,"scan_hit_samples":enemy_manager.scan_light.hit_samples,"player_health":player.health,"attack_states":gull_actor.visited_states.keys(),"crashes":gull_crashes,"lost_rotor":gull_actor.state.lostRotor,"combat_stats":combat.stats,"native_skeletons":source_scene.skeletons.size(),"scope":"native Gull flight/gimbal/rotors/attack requests, controlled ray damage, rotor loss/crash explosion and pool retirement, real source bolts/player damage and shared scan light and enemy muzzle flash; full missions and remaining rendering pending"}
   var file=FileAccess.open("res://evidence/gull-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
  return
 if enemy_pool_preview:
  enemy_pool_frame+=1
  if enemy_pool_frame==60:
   for i in 7:pool_preview_actors[i].damage(500,pool_preview_actors[i].state.headPos,Vector3.RIGHT,"body")
  if enemy_pool_frame==61:
   var reused=enemy_manager.spawn("hound",Vector3(-29,0,6),{"yaw":0,"passive":true,"patrolRadius":.1})
   pool_preview_reused_id=reused.state.id if reused!=null else -1
  enemy_manager.update(1.0/60);impact_effects.update(1.0/60);light_pool.update(1.0/60)
  if enemy_pool_frame in [30,80,240,590]:_enemy_pool_still(enemy_pool_frame)
  if enemy_pool_frame>=600:
   var ids=[]
   for actor in enemy_manager.active:ids.append(actor.state.id)
   var report={"frames":enemy_pool_frame,"pool_hounds":enemy_manager.pools.hound.size(),"active":enemy_manager.active.size(),"alive":enemy_manager.alive_count(),"wrecks":enemy_manager.wrecks.size(),"reused_id":pool_preview_reused_id,"next_id":enemy_manager.next_id,"active_ids":ids,"time":enemy_coordinator.time,"tokens":enemy_coordinator.tokens,"scope":"eight native Hounds, seven controlled kills, oldest retained-wreck reuse, capped wreck queue and old-wreck sink retirement; Gull and mission spawning pending"}
   var file=FileAccess.open("res://evidence/enemy-pool-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
  return
 if hound_actor_preview:
  hound_actor_frame+=1
  if hound_combat_preview:
   if player.alive:
    camera.look_at(hound_actor.state.headPos,Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x
   var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":hound_actor_frame>150,"fire":hound_actor_frame>=180 and hound_actor_frame<600 and hound_actor.state.alive,"jump":false,"reload":hound_actor_frame==480,"ads_value":weapon.ads}
   player.update(1.0/60,input,camera);_advance_weapon(1.0/60,input)
  else:
   if hound_actor_frame==300:hound_actor.damage(30,hound_actor.state.headPos,Vector3(1,0,0),"weak")
   if hound_actor_frame==420:hound_actor.damage(200,hound_actor.state.headPos,Vector3(1,0,0),"body")
  if not hound_combat_preview:enemy_manager.update(1.0/60);impact_effects.update(1.0/60);light_pool.update(1.0/60)
  camera.look_at(hound_actor.state.pos+Vector3(0,.6,0),Vector3.UP);view_camera.global_transform=camera.global_transform
  if hound_actor_frame in [180,419,450,540,890]:_hound_actor_still(hound_actor_frame)
  if hound_actor_frame>=900:
   var report={"frames":hound_actor_frame,"shots":hound_actor.shots_fired,"player_hits":hound_actor_player_hits,"player_health":player.health,"player_min_health":player_min_health,"player_damage_events":player_damage_events,"player_alive":player.alive,"impacts":hound_actor.impacts_received,"states":hound_actor.visited_states.keys(),"steps":hound_actor.pose.steps,"alive":hound_actor.state.alive,"active":hound_actor.state.active,"wreck":hound_actor.state.wreck,"die_time":hound_actor.state.dieT,"body_height":hound_actor.state.sY.x,"particles":impact_effects.pool.particles.size()+impact_effects.lit_pool.particles.size(),"combat_stats":combat.stats,"scope":"native Hound actor with real combat damage; full enemy manager, Gull, missions and UI pending"}
   var file=FileAccess.open("res://evidence/hound-combat-runtime.json" if hound_combat_preview else "res://evidence/hound-actor-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
  return
 if hound_preview:
  hound_frame+=1
  var frame=hound_frame-1;var state:Dictionary=hound_pose.state
  if hound_route_preview:
   hound_locomotion.follow_goal(1.0/60,3.4);hound_locomotion.move(1.0/60,[state])
  else:
   state.prevSpeed=state.speed;state.speed=minf(3,frame*.04) if frame<120 else maxf(0,3-(frame-120)*.05)
   state.yawRate=.45 if frame>=60 and frame<160 else 0;state.yaw+=state.yawRate/60
   state.pos.x+=sin(state.yaw)*state.speed/60;state.pos.z+=cos(state.yaw)*state.speed/60
  hound_pose.step(1.0/60);hound_pose.pose(1.0/60,float(hound_frame)/60)
  camera.look_at(state.pos+Vector3(0,.6,0),Vector3.UP);view_camera.global_transform=camera.global_transform
  if hound_frame in [30,90,150,220]:_hound_still(hound_frame)
  if hound_frame>=(720 if hound_route_preview else 240):
   var report={"frames":hound_frame,"fps":60,"steps":hound_pose.steps,"native_skeletons":source_scene.skeletons.size(),"scope":"controlled movement with native world-foot stepping and IK, not full AI"}
   if hound_route_preview:report.merge({"scope":"native source path following plus procedural feet and IK, not full AI","arrived":not state.hasGoal,"replans":hound_locomotion.replans,"position":[state.pos.x,state.pos.y,state.pos.z]})
   var file=FileAccess.open("res://evidence/hound-route-runtime.json" if hound_route_preview else "res://evidence/hound-pose-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();get_tree().quit()
  return
 if barrel_preview:
  barrel_frame+=1
  var frame=barrel_frame
  var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":frame<65,"fire":frame>=45 and frame<56,"jump":false,"ads_value":weapon.ads}
  player.update(1.0/30,input,camera);_advance_weapon(1.0/30,input);view_camera.global_transform=camera.global_transform
  if frame==280:
   barrel_blast_count=explosives.blasts
   for binding in explosives.items[6].inst:
    var node:MultiMeshInstance3D=source_scene.source_nodes[binding.im["$node"]]
    if absf(node.multimesh.get_instance_transform(int(binding.i)).basis.determinant())<.000001:barrel_hidden_slots+=1
  if frame==330:explosives.reset()
  if frame in [20,49,55,100,280,350]:_barrel_still(frame)
  if frame>=390:
   var restored=0
   for binding in explosives.items[6].inst:
    var node:MultiMeshInstance3D=source_scene.source_nodes[binding.im["$node"]]
    var actual=node.multimesh.get_instance_transform(int(binding.i));var expected=source_scene._transform(binding.m)
    if actual.origin.distance_to(expected.origin)<.0001 and actual.basis.x.distance_to(expected.basis.x)<.0001 and actual.basis.y.distance_to(expected.basis.y)<.0001 and actual.basis.z.distance_to(expected.basis.z)<.0001:restored+=1
   var report={"frames":frame,"fps":30,"shots":weapon.shot_count,"blasts_before_reset":barrel_blast_count,"hidden_gpu_slots_before_reset":barrel_hidden_slots,"source_barrel_slots":explosives.items[6].inst.size(),"alive_after_reset":explosives.alive_count(),"source_explosive_assets":explosives.items.size(),"remaining_particles":impact_effects.pool.particles.size()+impact_effects.lit_pool.particles.size(),"remaining_debris":impact_effects.debris.live}
   report.merge({"restored_gpu_slots_after_reset":restored,"collision_boxes_after_reset":player.physics.boxes.size()})
   var file=FileAccess.open("res://evidence/barrel-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();get_tree().quit()
  return
 if explosion_preview:
  explosion_frame+=1
  var frame=explosion_frame
  if frame==30:explosion_effects.explode(Vector3(-18,.45,6),1.9)
  var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":false,"fire":false,"jump":false,"ads_value":weapon.ads}
  player.update(1.0/30,input,camera);_advance_weapon(1.0/30,input);view_camera.global_transform=camera.global_transform
  if frame in [31,36,45,75,180]:_explosion_still(frame)
  if frame>=330:
   var report={"frames":frame,"fps":30,"explosions":explosion_effects.count,"additive_particles":impact_effects.pool.emitted,"lit_particles":impact_effects.lit_pool.emitted,"remaining_additive":impact_effects.pool.particles.size(),"remaining_lit":impact_effects.lit_pool.particles.size(),"debris":impact_effects.debris.emitted,"remaining_debris":impact_effects.debris.live,"smolder_emitters":explosion_effects.emitters.size(),"light_flashes":light_pool.emitted,"scorches":decals.emitted}
   var file=FileAccess.open("res://evidence/explosion-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();get_tree().quit()
  return
 if weapon_preview:
  weapon_preview_frame+=1
  var frame=weapon_preview_frame
  var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":frame>=30 and frame<60,"fire":(frame>=60 and frame<90) or frame==195,"jump":false,"ads_value":weapon.ads,"reload":frame==90 or frame==210,"weapon2":frame==170}
  player.update(1.0/30,input,camera);_advance_weapon(1.0/30,input)
  view_camera.global_transform=camera.global_transform
  if frame in [45,120,200,235]:_weapon_preview_still(frame)
  if frame>=(420 if "--effects-lifecycle" in OS.get_cmdline_user_args() else 300):
   var report={"frames":frame,"fps":30,"shots":weapon.shot_count,"current":weapon.current,"slots":str(weapon.slots),"native_skeletons":source_scene.skeletons.size(),"world_fov":camera.fov,"viewmodel_fov":view_camera.fov,"flashes":weapon_effects.flashes_emitted,"shells":shells.emitted,"shell_bounces":shells.bounces,"shells_settled":shells.settled,"tracers":tracers.emitted}
   report.merge({"impacts":impact_effects.impacts,"additive_particles":impact_effects.pool.emitted,"lit_particles":impact_effects.lit_pool.emitted,"maximum_additive_live":impact_effects.maximum_live,"remaining_additive":impact_effects.pool.particles.size(),"remaining_lit":impact_effects.lit_pool.particles.size()})
   report.merge({"debris":impact_effects.debris.emitted,"debris_bounces":impact_effects.debris.bounces,"debris_settled":impact_effects.debris.settled,"remaining_debris":impact_effects.debris.live})
   var file=FileAccess.open("res://evidence/weapon-preview.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();get_tree().quit()
  return
 if preview_mode:
  preview_frame+=1
  var progress=clampf(float(preview_frame-20)/180.0,0.0,1.0)
  camera.transform=preview_start
  camera.position+=preview_start.basis*Vector3(sin(progress*TAU)*.35,0,-progress*1.8)
  camera.rotate_y(sin(progress*TAU)*.10)
  if preview_frame==80 or preview_frame==160:_preview_still(preview_frame)
  if preview_frame>=200:get_tree().quit()
  return
 if capture_mode:return

func _physics_process(dt:float)->void:
 if game_mode:
  if not flow_preview:_game_tick(minf(dt,.05))
  return
 if sky_preview or rain_preview or sea_preview or capture_mode or preview_mode or weapon_preview or explosion_preview or barrel_preview or hound_preview or hound_actor_preview or enemy_pool_preview or gull_preview or mission_preview or player==null:return
 var movement=Vector2(float(source_keyboard_input.down("right"))-float(source_keyboard_input.down("left")),float(source_keyboard_input.down("forward"))-float(source_keyboard_input.down("back"))).limit_length()
 var input={"move":movement,"sprint":Input.is_physical_key_pressed(KEY_SHIFT),"crouch":Input.is_physical_key_pressed(KEY_CTRL),"ads":Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),"fire":Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),"jump":jump_pending or source_gamepad_input.pressed.has("jump"),"ads_value":weapon.ads}
 if mission:mission.update(minf(dt,.05),Input.is_physical_key_pressed(KEY_E));_mission_hud()
 player.update(dt,input,camera)
 input.merge(weapon_actions);_advance_weapon(dt,input);weapon_actions.clear()
 jump_pending=false

func _advance_weapon(dt:float,input:Dictionary)->void:
 var was_alive=player.alive
 if not was_alive:weapon_animation.drop_view.advance(dt,weapon,player,impact_effects)
 for gun in weapon.rigs:
  weapon.magazine_motion.root_rotations[gun]=source_scene.source_nodes[weapon.rigs[gun].root["$node"]].quaternion
 if not player.alive or not player.enabled:input.fire=false;input.reload=false;input.swap=false
 weapon.update(dt,input,player)
 var live_root:Variant=weapon.step_root(dt,input,player) if was_alive else null
 weapon_animation.update(weapon,live_root)
 enemy_manager.update(dt)
 explosives.update(dt)
 _advance_effects(dt)
 if weapon_animation.drop_view.motion.active:source_scene.source_nodes[weapon.rigs[weapon.current].flash["$node"]].visible=false
 var slot:Dictionary=weapon.slots[weapon.current]
 ammo_label.text="%s  %d / %s\n%s  HP %d"%[weapon.rigs[weapon.current].name,slot.ammo,"∞" if is_inf(slot.reserve) else str(int(slot.reserve)),weapon.state,int(player.health)]

func _advance_effects(dt:float)->void:
 if not (dt>0):dt=0
 weapon_effects.update(dt)
 impact_effects.clock+=dt
 explosion_effects.update(dt)
 impact_effects.update(dt,false)
 shells.update(dt)
 if not game_mode:light_pool.update(dt)

func _weapon_preview_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/weapon-%03d.png"%frame)

func _explosion_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/explosion-%03d.png"%frame)

func _barrel_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/barrel-%03d.png"%frame)

func _hound_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(("res://evidence/hound-route-%03d.png" if hound_route_preview else "res://evidence/hound-%03d.png")%frame)

func _weapon_fired(id:String,definition:Dictionary,spread:float)->void:
 weapon_animation.last_shot=weapon.time
 # Original Q reads the old root and consumes spread before shell/recoil/flash.
 var direction=camera.global_basis*weapon.sample_spread(spread)
 last_impact=combat.player_shot(player.eye,direction,definition.damage,definition.range)
 var end:Vector3=last_impact.point if not last_impact.is_empty() else player.eye+direction*definition.range
 impact_effects.tracer(weapon_effects.muzzle_world(id),end)
 var rig:Dictionary=weapon.rigs[id];var root:Node3D=source_scene.source_nodes[rig.root["$node"]]
 var local=root.transform*Vector3(rig.eject[0],rig.eject[1],rig.eject[2])
 var ratio=tan(deg_to_rad(camera.fov)*.5)/tan(deg_to_rad(54)*.5);local.x*=ratio;local.y*=ratio
 var shell_velocity=camera.global_basis*weapon.sample_shell_velocity()+player.velocity
 shells.emit(camera.global_transform*local,shell_velocity)
 weapon_effects.flash_light(id,definition)
 enemy_manager.weapon_fire(player.eye)
 weapon.apply_recoil(player)
 weapon_effects.fire(id,definition,false)

 _pad_rumble(.35 if id=="pistol" else .18,.6 if id=="pistol" else .5,55)

func _preview_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/native-preview-%03d.png"%frame)

func _capture(exit_after:bool=true)->void:
 for i in 12:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image=get_viewport().get_texture().get_image();image.save_png("res://evidence/native-assets.png")
 if "--impact-probe" in OS.get_cmdline_user_args():image.save_png("res://evidence/impact-probe.png")
 if "--tracer-probe" in OS.get_cmdline_user_args():image.save_png("res://evidence/tracer-probe.png")
 if "--splash-probe" in OS.get_cmdline_user_args():image.save_png("res://evidence/splash-probe.png")
 if "--debris-probe" in OS.get_cmdline_user_args():image.save_png("res://evidence/debris-probe.png")
 if "--flash-probe" in OS.get_cmdline_user_args():
  view_port.get_texture().get_image().save_png("res://evidence/flash-viewmodel.png")
  image.save_png("res://evidence/flash-probe.png")
  var flash=weapon_effects.flashes.rifle
  print("FLASH_PROBE "+str({"visible":flash.node.is_visible_in_tree(),"intensity":flash.material.get_shader_parameter("uInt"),"position":flash.node.global_position,"camera":view_camera.global_position,"type_format":flash.node.mesh.surface_get_format(0)}))
 var report=source_scene.report.duplicate(true);report["adapter"]=RenderingServer.get_video_adapter_name();report["engine"]=Engine.get_version_info();report["image_size"]=[image.get_width(),image.get_height()];report["stage"]="native asset integration, not full replica"
 var f=FileAccess.open("res://evidence/native-runtime.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("NATIVE_ASSET_CAPTURE_OK")
 if exit_after:get_tree().quit()

func _hound_actor_shot(origin:Vector3,direction:Vector3,damage:float)->void:
 var world_hit=player.physics.raycast(origin,direction,200)
 var player_hit=combat.enemy_shot(origin,direction,damage,200)
 if player_hit:hound_actor_player_hits+=1
 var distance=origin.distance_to(player.pos+Vector3.UP) if player_hit else (world_hit.dist if not world_hit.is_empty() else 90)
 impact_effects.tracer(origin,origin+direction*distance,{"color":16760944,"speed":260,"width":.035})
 impact_effects.enemy_muzzle_flash(origin,direction,.9)
 light_pool.flash(origin,16756832,22,7,.05)

func _weapon_smoke_requested(options:Dictionary)->void:
 impact_effects.smoke(weapon_effects.muzzle_world(weapon.current),options)

func _player_motion_effects(kind:String,payload:Dictionary)->void:
 impact_effects.player_motion_event(kind,payload,player.pos)
 if kind=="rescued" and mission.state=="playing":mission.message.emit("Hauled out of the water",2.5)

func _impact_visuals(hit:Dictionary,direction:Vector3)->void:
 if hit.is_empty():return
 var surface=impact_effects.impact(hit,direction)
 var resolved=hit.duplicate();resolved.surface=surface
 var normal:Vector3=hit.normal
 resolved.normal=Vector3.UP if normal.length_squared()<1e-6 else normal.normalized()
 decals.impact(resolved)

func _combat_impact(hit:Dictionary)->void:
 _impact_visuals(hit,hit.dir)
 if explosives!=null:
  var damage=float(weapon.rigs[weapon.current].def.get("damage",26)) if hit.get("from")=="player" else 9.0
  if hit.get("from")=="player" and damage==0:damage=26
  explosives.impact(hit,damage)

func _hound_actor_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(("res://evidence/hound-combat-%03d.png" if hound_combat_preview else "res://evidence/hound-actor-%03d.png")%frame)

func _exit_tree()->void:
 _dispose_game()

func _player_hit(amount:float,_from_position:Variant)->void:
 player_min_health=minf(player_min_health,player.health)
 player_damage_events.append({"amount":amount,"health":player.health,"frame":hound_actor_frame})
 if player_damage_events.size()>512:player_damage_events.pop_front()

func _enemy_pool_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/enemy-pool-%03d.png"%frame)

func _gull_bolt_request(position:Vector3,direction:Vector3)->void:
 gull_bolt_requests+=1;enemy_manager.bolts.fire(position,direction);impact_effects.enemy_muzzle_flash(position,direction,.55)
 if gull_preview:_gull_fire_still(gull_preview_frame)

func _gull_explosion(position:Vector3,radius:float,damage:float)->void:combat.explode(position,radius,damage,"enemy")

func _gull_blast_effect(position:Vector3,size:float)->void:
 gull_crashes+=1;explosion_effects.explode(position,size)

func _gull_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/gull-%03d.png"%frame)

func _gull_fire_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/gull-fire-%03d.png"%frame)

func _dispose_game()->void:
 if player!=null and player.hit.is_connected(_pad_player_hit):player.hit.disconnect(_pad_player_hit)
 if explosion_effects!=null and explosion_effects.exploded.is_connected(_pad_explosion):explosion_effects.exploded.disconnect(_pad_explosion)
 if post_pipeline!=null:post_pipeline.dispose()
 if planar_reflection!=null:planar_reflection.dispose();planar_reflection=null
 if source_ibl_service!=null:source_ibl_service.dispose();source_ibl_service=null
 if source_sun_service!=null:source_sun_service.dispose();source_sun_service=null
 if source_local_light_service!=null:source_local_light_service.dispose();source_local_light_service=null
 if source_local_light_data!=null:source_local_light_data.dispose();source_local_light_data=null
 if sun_shadow_pass!=null:sun_shadow_pass.dispose();sun_shadow_pass=null
 if game_ui:game_ui.dispose()
 if game_flow:game_flow.dispose()
 if game_mode:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 if mission:mission.dispose()
 if enemy_manager:enemy_manager.dispose()

func _mission_resupply(amount:int,cap:int,reset:bool)->void:
 weapon.slots.rifle.reserve=minf(cap,weapon.slots.rifle.reserve+amount)
 if reset:explosives.reset()

func _mission_hud()->void:
 if mission_label==null:return
 mission_label.text="%s\nRelays %d / %d | Alive %d | Queued %d\n%s %s"%[mission.objective_text(),mission.run.cut,mission.relays.size(),enemy_manager.alive_count(),mission.run.queue.size(),mission_prompt,"%d%%"%int(mission_progress*100) if not mission_prompt.is_empty() else ""]
 if mission.state=="complete":mission_label.text="Extraction complete\nRating: %s | Time %.1fs"%[mission.debrief.rating,mission.debrief.time]
 if mission.state=="dead":mission_label.text="Breacher down"

func _mission_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/mission-%03d.png"%frame)

func _setup_game()->void:
 status.visible=false;ammo_label.visible=false
 mission=SaltlineMission.new(source_scene.source.modules.level,enemy_manager,player,navigation,source_bootstrap.root)
 mission.relay_changed.connect(relay_visuals.set_state);mission.resupply.connect(_mission_resupply)
 session=SaltlineSession.new();session.mission=mission;session.player=player;session.weapon=weapon;session.camera=camera;session.effects=impact_effects;session.explosions=explosion_effects;session.explosives=explosives;session.shells=shells;session.tracers=tracers;session.decals=decals;session.weapon_effects=weapon_effects;session.animation=weapon_animation
 game_flow=SaltlineGameFlow.new(mission,camera,"" if flow_preview else "user://saltline-holdout.json")
 game_flow.world_time=animation_time
 game_flow.reset_requested.connect(_reset_session);game_flow.state_changed.connect(_app_state)
 game_flow.capture_mouse.connect(func(capture):Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if capture and not flow_preview and not source_touch_input.enabled else Input.MOUSE_MODE_VISIBLE)
 game_ui=SaltlineGameUI.new();add_child(game_ui);game_ui.setup(game_flow,weapon,_settings_path(),post_pipeline.material)
 original_audio=preload("res://scripts/original_audio.gd").new();add_child(original_audio);original_audio.setup(self)
 game_ui.touch_input=source_touch_input
 source_keyboard_input.other_held=func(action):return source_gamepad_input.down(action) or source_touch_input.down(action)
 touch_overlay=preload("res://scripts/touch_overlay.gd").new();touch_overlay.input=source_touch_input;touch_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;touch_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);game_ui.root.add_child(touch_overlay);touch_overlay.visible=false
 player.hit.connect(_pad_player_hit);explosion_effects.exploded.connect(_pad_explosion)
 render_quality=preload("res://scripts/render_quality.gd").new();render_quality.configure(OS.get_cmdline_args(),OS.get_cmdline_user_args(),flow_preview);game_ui.setting_changed.connect(_render_setting_changed)
 render_quality.apply(self,render_quality.startup_name(game_ui.settings.quality,OS.get_cmdline_user_args(),str(source_scene.source.quality.name)))
 game_ui.comms.line_started.connect(func(text):radio_reports.append({"frame":flow_preview_frame,"text":text}))
 view_camera.cull_mask=0;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _render_setting_changed(key:String,value:Variant)->void:
 if key=="quality":render_quality.apply(self,str(value))

func _app_state(value:String)->void:
 if value not in ["intro","playing"]:source_keyboard_input.clear();source_gamepad_input.clear_gameplay();source_touch_input.clear();touch_buttons.clear();source_mouse_buttons.clear()
 source_mouse_input.clear()
 flow_history.append({"state":value,"frame":flow_preview_frame});view_camera.cull_mask=0 if value=="title" else 2

func _reset_session(mode:String,keep:bool)->void:
 source_mouse_input.clear()
 session.reset(mode,keep);weapon_actions.clear();jump_pending=false;mission_prompt="";mission_progress=0
 var shells_live=0
 for slot in shells.slots:
  if slot.state!=0:shells_live+=1
 reset_reports.append({"frame":flow_preview_frame,"health":player.health,"alive":player.alive,"ammo":weapon.slots.rifle.ammo,"reserve":weapon.slots.rifle.reserve,"weapon":weapon.current,"explosives":explosives.alive_count(),"boxes":player.physics.boxes.size(),"particles":impact_effects.pool.particles.size()+impact_effects.lit_pool.particles.size(),"debris":impact_effects.debris.live,"shells":shells_live,"decals":decals.slots.size(),"emitters":explosion_effects.emitters.size(),"enemies":enemy_manager.alive_count(),"retries":mission.run.retries,"radio_queue":game_ui.comms.queue.size(),"radio_active":not game_ui.comms.current.is_empty()})

func _game_tick(dt:float,override:Dictionary={})->void:
 var input_gameplay=game_flow.state in ["intro","playing"]
 _poll_gamepad(dt)
 var held=bool(override.get("interact",false)) if flow_preview else source_keyboard_input.down("interact") or source_gamepad_input.down("interact") or source_touch_input.down("interact")
 # Preserve the paused debounce gate, then consume Start at the panel layer.
 if pause_pending and game_flow.state=="paused" and game_flow.pause_delay<=0 and game_ui.panel_open:
  game_ui.close_panel();pause_pending=false
 var simulate=game_flow.update(dt,held,pause_pending);pause_pending=false
 if simulate:
  var movement=Vector2.ZERO if flow_preview else Vector2(float(source_keyboard_input.down("right"))-float(source_keyboard_input.down("left")),float(source_keyboard_input.down("forward"))-float(source_keyboard_input.down("back")))
  movement=(movement+Vector2(source_gamepad_input.move[0],source_gamepad_input.move[1])+Vector2(source_touch_input.move[0],source_touch_input.move[1])).limit_length()
  var input={"move":movement,"sprint":false if flow_preview else source_keyboard_input.down("sprint") or source_gamepad_input.down("sprint"),"crouch":false if flow_preview else source_keyboard_input.down("crouch") or source_gamepad_input.down("crouch"),"ads":false if flow_preview else _mouse_down(MOUSE_BUTTON_RIGHT) or source_gamepad_input.down("ads"),"fire":false if flow_preview else _mouse_down(MOUSE_BUTTON_LEFT) or source_keyboard_input.down("fire") or source_gamepad_input.down("fire"),"jump":jump_pending or source_gamepad_input.pressed.has("jump"),"ads_value":weapon.ads}
  input.merge(override,true);input.merge(weapon_actions,true)
  if not flow_preview:
   input.fire=input.fire or source_touch_input.down("fire");input.ads=input.ads or source_touch_input.ads;input.sprint=input.sprint or source_touch_input.sprint();input.jump=input.jump or source_touch_input.pressed.has("jump")
  if not input_gameplay and not flow_preview:input.ads=false;input.fire=false;input.move=Vector2.ZERO;input.sprint=false;input.crouch=false
  if game_flow.state not in ["intro","playing"]:input.ads=false;input.fire=false;input.move=Vector2.ZERO;input.jump=false;input.sprint=false;input.crouch=false
  if not flow_preview and input_gameplay:
   var turning=source_keyboard_input.turning()
   source_mouse_input.keyboard(turning.x,turning.y,dt)
  if game_flow.state=="playing":source_gamepad_input.update_assist(dt,input_device=="pad",_pad_assist_target)
  source_mouse_input.dx+=source_touch_input.look[0];source_mouse_input.dy+=source_touch_input.look[1]
  var look=source_mouse_input.consume()
  if not (input.get("look") is Dictionary):input.look=look
  player.ads=clampf(weapon.ads,0.0,1.0)
  player.look_normalized(float(input.look.get("dx",0.0)),float(input.look.get("dy",0.0)))
  player.update(dt,input,camera);_advance_weapon(dt,input);weapon_actions.clear();jump_pending=false
 else:
  source_mouse_input.clear()
  if game_flow.state!="paused":_advance_effects(dt)
 source_touch_input.end_frame()
 if touch_overlay!=null:
  game_ui.status_hud.touch_layout=source_touch_input.enabled
  game_ui.radio.touch_layout=source_touch_input.enabled;game_ui.navigation_hud.touch_layout=source_touch_input.enabled
  touch_overlay.visible=source_touch_input.enabled and game_flow.state in ["intro","playing"]
  touch_overlay.prompt=game_ui.status_hud.interaction.active;touch_overlay.queue_redraw()

func _read_gamepad()->Variant:return gamepad_device.read()
func _settings_path()->String:return "" if flow_preview else "user://saltline-settings.json"
func _mouse_down(button:int)->bool:return bool(source_mouse_buttons.get(button,false))
func _touch_event(event:InputEvent)->bool:
 if event is InputEventScreenTouch and event.pressed:touch_last_start_ms=Time.get_ticks_msec()
 var gameplay=game_flow.state in ["intro","playing"]
 if not source_touch_input.enabled and event is InputEventScreenTouch and event.pressed:
  source_touch_input.enabled=true;input_device="touch";Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var point=event.position;var id=event.index
 if event is InputEventScreenDrag:
  if not gameplay:return false
  source_touch_input.motion(id,point.x,point.y,float(game_ui.settings.sens),bool(game_ui.settings.invertY));return true
 if event.pressed:
  if not gameplay:return false
  var action=touch_overlay.hit(point)
  if not action.is_empty():
   touch_buttons[id]=action
   var external=source_keyboard_input.held.keys();external.append_array(source_gamepad_input.held.keys())
   if _mouse_down(MOUSE_BUTTON_LEFT):external.append("fire")
   source_touch_input.button(action,id,true,point.x,point.y,external)
   if source_touch_input.pressed.has(action):
    if action=="pause":pause_pending=true
    elif action in ["reload","swap"]:weapon_actions[action]=true
   return true
  source_touch_input.start(id,point.x,point.y,get_viewport().get_visible_rect().size.x,gameplay);return true
 if touch_buttons.has(id):
  source_touch_input.button(touch_buttons[id],id,false);touch_buttons.erase(id);return true
 source_touch_input.finish(id);return gameplay

func _poll_gamepad(dt:float)->void:
 if flow_preview:
  source_gamepad_input.move=[0.0,0.0];source_gamepad_input.look=[0.0,0.0];source_gamepad_input.pressed.clear();source_gamepad_input.ui.clear();return
 var external=source_keyboard_input.held.keys()
 external.append_array(source_touch_input.held.keys())
 if _mouse_down(MOUSE_BUTTON_LEFT):external.append("fire")
 if _mouse_down(MOUSE_BUTTON_RIGHT):external.append("ads")
 source_gamepad_input.device=input_device
 source_gamepad_input.poll(_read_gamepad(),dt,game_flow.state in ["intro","playing"],game_ui.status_hud.interaction.active,Time.get_ticks_msec(),float(game_ui.settings.sens),bool(game_ui.settings.invertY),external)
 input_device=source_gamepad_input.device;game_ui.status_hud.input_device=input_device
 source_mouse_input.dx+=source_gamepad_input.look[0];source_mouse_input.dy+=source_gamepad_input.look[1]
 var menu=source_gamepad_input.ui
 if game_flow.menu!="none":
  if menu.has("up"):game_ui.pad_nav(-1)
  elif menu.has("down"):game_ui.pad_nav(1)
  if menu.has("left"):game_ui.pad_adjust(-1)
  elif menu.has("right"):game_ui.pad_adjust(1)
  if menu.has("accept"):game_ui.pad_accept()
  elif menu.has("back"):
   if game_ui.panel_open:game_ui.close_panel()
   elif game_flow.state=="paused":game_flow.resume()
  elif menu.has("start") and game_flow.state!="paused":
   if game_ui.panel_open:game_ui.close_panel()
   game_ui.pad_primary()
 if source_gamepad_input.pressed.has("pause"):pause_pending=true
 if game_flow.state in ["intro","playing"]:
  for action in ["reload","swap","weapon1","weapon2"]:
   if source_gamepad_input.pressed.has(action):weapon_actions[action]=true

func _pad_assist_target()->bool:
 var direction=-camera.global_transform.basis.z;var hit=combat.raycast(player.eye,direction,60)
 return not hit.is_empty() and player.physics.raycast(player.eye,direction,float(hit.dist)).is_empty()

func _pad_rumble(strong:float,weak:float,duration_ms:float)->void:
 if input_device!="pad" or not source_gamepad_input.connected:return
 var request={"strong":minf(1,strong),"weak":minf(1,weak),"milliseconds":duration_ms}
 rumble_requests.append(request)
 if rumble_requests.size()>32:rumble_requests.pop_front()
 if gamepad_device.device_id>=0:Input.start_joy_vibration(gamepad_device.device_id,request.weak,request.strong,duration_ms/1000)

func _pad_player_hit(amount:float,_position:Variant)->void:_pad_rumble(minf(1,.45+amount/30),.3,160)
func _pad_explosion(position:Vector3,size:float)->void:
 var value=clampf(1-player.pos.distance_to(position)/22,0,1)*minf(1.2,size if size!=0 else 1.0)
 if value>.05:_pad_rumble(minf(1,value),minf(1,value*.8),240+200*value)

func _game_input_event(event:InputEvent)->void:
 if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==-1:return
 if source_touch_input.enabled:
  if event is InputEventMouseMotion:return
  if event is InputEventMouseButton and event.pressed and Time.get_ticks_msec()-touch_last_start_ms<800:return
 if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and game_flow.state in ["intro","playing"]:
  if source_mouse_input.motion(event.relative.x,event.relative.y,float(game_ui.settings.sens),bool(game_ui.settings.invertY)) and event.relative!=Vector2.ZERO:input_device="kbm"
 if event is InputEventMouseButton and event.pressed and game_flow.state in ["intro","playing"]:
  if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   if source_mouse_input.wheel(Time.get_ticks_msec(),event.factor):weapon_actions.swap=true
   return
  input_device="kbm"
  if not source_touch_input.enabled:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  source_mouse_buttons[event.button_index]=true
 if not event is InputEventKey:return
 var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
 if code==KEY_F12 and event.pressed and not event.echo:_capture(false);return
 if event.pressed and not event.echo and source_keyboard_input.ACTIONS.has(code):input_device="kbm"
 var new_press=source_keyboard_input.key(code,event.pressed,event.echo)
 if not new_press:return
 if code in [KEY_ESCAPE,KEY_P]:
  if game_ui.panel_open:game_ui.close_panel()
  else:pause_pending=true
  return
 if code in [KEY_ENTER,KEY_KP_ENTER] and game_flow.state=="title" and not game_ui.panel_open:game_flow.start();return
 if game_flow.state not in ["intro","playing"]:return
 if code==KEY_SPACE:jump_pending=true
 if code==KEY_R:weapon_actions.reload=true
 if code in [KEY_1,KEY_KP_1]:weapon_actions.weapon1=true
 if code in [KEY_2,KEY_KP_2]:weapon_actions.weapon2=true
 if code==KEY_Q:weapon_actions.swap=true

func _flow_preview_step(dt:float)->void:
 if planar_preview:_planar_preview_step(dt);return
 if source_sun_preview:_source_sun_preview_step(dt);return
 if motion_preview:_motion_preview_step(dt);return
 if volume_preview:_volume_preview_step(dt);return
 if ao_preview:_ao_preview_step(dt);return
 if solar_preview:_solar_preview_step(dt);return
 if sight_preview:_sight_preview_step(dt);return
 if status_preview:_status_preview_step(dt);return
 if feedback_preview:_feedback_preview_step(dt);return
 if navigation_preview:_navigation_preview_step(dt);return
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==50:game_ui.buttons.settings.pressed.emit()
 if frame==55:game_ui._select("sens",1.25);game_ui._select("fov",80);game_ui._select("invertY",true)
 if frame==65:game_ui.buttons.close.pressed.emit()
 if frame==70:game_ui._select("sens",1);game_ui._select("fov",74);game_ui._select("invertY",false)
 if frame==90:game_ui.buttons.deploy.pressed.emit()
 if frame==210 or frame==560:pause_pending=true
 if frame==215:pause_snapshot={"enemy_time":enemy_coordinator.time,"weapon_time":weapon.time,"mission_time":mission.run.time,"rain_time":rain_system.time}
 if frame in [215,245,251]:flow_clock_samples.append({"frame":frame,"material":timed_materials[0].get_shader_parameter("uTime"),"rain":rain_system.time,"global":animation_time})
 if frame==245:pause_unchanged=pause_snapshot=={"enemy_time":enemy_coordinator.time,"weapon_time":weapon.time,"mission_time":mission.run.time,"rain_time":rain_system.time}
 if frame==225:game_ui.buttons.settings.pressed.emit()
 if frame==230:game_ui._select("fov",78)
 if frame==240:game_ui.buttons.close.pressed.emit()
 if frame==250:game_ui.buttons.resume.pressed.emit()
 if frame==270:
  player.invulnerable=true;weapon.slots.rifle.ammo=3;weapon.slots.rifle.reserve=7;weapon.reload_now();explosives.damage_item(0,1000)
  impact_effects.debris.emit(player.pos+Vector3(0,1,0),Vector3.ONE,Vector3.ONE*.03,Vector3.ONE,10,0)
 if frame==280:player.invulnerable=false;player.damage(200,player.pos)
 if frame==390:game_ui.buttons.retry.pressed.emit()
 if frame==600:game_ui.buttons.restart.pressed.emit()
 _game_tick(dt,{"fire":frame>=260 and frame<269})
 if frame in [45,60,180,215,235,375,420,550,620]:_flow_still(frame)
 if frame>=780:
  var report={"frames":frame,"state":game_flow.state,"menu":game_flow.menu,"history":flow_history,"pause_frozen":pause_unchanged,"world_clock_samples":flow_clock_samples,"radio_lines":radio_reports,"radio_visible":game_ui.comms.visible,"resets":reset_reports,"retries":mission.run.retries,"scope":"native title/intro/pause/death/retry/restart through UI button signals, actual dirty-state resets; automated inputs, full original HUD/settings and visual calibration pending"}
  var file=FileAccess.open("res://evidence/game-flow-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()

func _flow_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/flow-%03d.png"%frame)

func _navigation_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==60:game_ui.buttons.deploy.pressed.emit();player.invulnerable=true
 if frame>=240 and frame<420:player.look(Vector2(5,cos(frame*.03)*.5))
 if frame in [450,510,570]:mission.cut_relay(mission.relays[int((frame-450)/60)])
 _game_tick(dt,{"ads":frame>=180 and frame<230 or frame>=650 and frame<700,"fire":frame>=430 and frame<440})
 if frame in [170,215,300,440,460,520,590,675,730]:_navigation_still(frame)
 if frame>=780:
  var report={"frames":frame,"snapshots":navigation_reports,"cut":mission.run.cut,"radio_lines":radio_reports,"scope":"Native navigation HUD in real game scene; automated camera sweep/ADS, direct cut_relay calls to verify marker lifecycle, not manual relay interaction acceptance"}
  var file=FileAccess.open("res://evidence/navigation-hud-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()

func _navigation_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/navigation-%03d.png"%frame)
 navigation_reports.append({"frame":frame,"ads":player.ads,"heading":game_ui.navigation_hud.current_heading,"markers":game_ui.navigation_hud.markers.duplicate(true),"crosshair":game_ui.navigation_hud.cross.duplicate(true)})

func _feedback_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==30:
  game_flow.start("mission",false,false,true);enemy_manager.clear()
  player.pos=Vector3(-24,0,6);player.safe_pos=player.pos;player.eye=player.pos+Vector3(0,1.68,0)
  feedback_actor=enemy_manager.spawn("hound",Vector3(-32,0,6),{"yaw":PI/2,"passive":true})
 if frame>30 and frame<290 and feedback_actor!=null:
  camera.global_position=player.eye;camera.look_at(feedback_actor.state.headPos,Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x
 if frame==100 or frame==150 or frame==200 or frame==260:
  var target:Vector3=feedback_actor.state.headPos if frame in [150,200] else feedback_actor.state.pos+Vector3(0,.4,0)
  var origin=target+Vector3.UP*2 if frame==200 else camera.global_position
  var hit=combat.player_shot(origin,(target-origin).normalized(),1000 if frame>=200 else 8)
  feedback_shots.append({"frame":frame,"enemy":hit.get("enemy")!=null,"part":hit.get("part",""),"killed":hit.get("killed",false)})
 if frame==240:feedback_actor=enemy_manager.spawn("hound",Vector3(-31,0,8),{"yaw":PI/2,"passive":true})
 if frame in [300,310,320,330,340]:
  var angle=float(frame-300)/10*PI*.5;player.damage(7,player.pos+Vector3(sin(angle)*5,0,-cos(angle)*5))
 if frame>=360 and frame<390:player.look(Vector2(10,0))
 if frame==400:pause_pending=true
 if frame==440:game_ui.buttons.resume.pressed.emit()
 if frame==500:game_ui.buttons.restart.pressed.emit() if game_flow.state=="paused" else game_flow.retry()
 _game_tick(dt)
 if frame in [101,151,201,261,341,380,405,445,510]:_feedback_still(frame)
 if frame>=600:
  var report={"frames":frame,"shots":feedback_shots,"snapshots":feedback_reports,"scope":"Native HUD driven by actual combat.player_shot hits/kills, real player.damage directional events and game retry; deterministic ray targets and damage sources, not manual combat acceptance"}
  var file=FileAccess.open("res://evidence/combat-feedback-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()

func _feedback_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/feedback-%03d.png"%frame)
 feedback_reports.append({"frame":frame,"kind":game_ui.feedback.hit_kind,"opacity":game_ui.feedback.hit_opacity,"scale":game_ui.feedback.hit_scale,"arcs":game_ui.feedback.arcs.duplicate(true),"feed":game_ui.feedback.feed.duplicate(true)})

func _ao_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:game_flow.start("mission",false,false,true);enemy_manager.clear()
 _game_tick(dt,{})
 camera.global_position=Vector3(-11,1.68,-23);camera.look_at(Vector3(5,.5,-21),Vector3.UP)
 post_pipeline.ao_enabled=frame>120;post_pipeline.volume_enabled=false
 if frame in [100,220]:_ao_still(frame)
 if frame>=240:
  var failures=[]
  if ao_reports.size()!=2:failures.append("missing AO snapshots")
  else:
   if ao_reports[0].ssao_enabled or ao_reports[1].ssao_enabled:failures.append("Godot SSAO still enabled")
   if ao_reports[1].minimum_ao>=.99 or ao_reports[1].darkened_samples<5:failures.append("source AO not contributing")
  var report={"frames":frame,"failures":failures,"snapshots":ao_reports,"scope":"Actual native sourceAO enabled vs disabled in frozen original warehouse view, zero dt/time freezes scene and film grain, existingGodotSSAO disabled. Original per-sample combine/sample0 plus nativeMSAA locations; crossbackend edges explicitly differ. Controlled camera and no enemies, not gameplay acceptance."}
  var file=FileAccess.open("res://evidence/ao-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"ao_preview_failures":failures}));_dispose_game();get_tree().quit()

func _ao_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/ao-%03d.png"%frame)
 var ao=post_pipeline.ao_ports[2].get_texture().get_image();var minimum=1.0
 for y in range(0,ao.get_height(),4):
  for x in range(0,ao.get_width(),4):minimum=minf(minimum,ao.get_pixel(x,y).r)
 var before=post_pipeline.scene_port.get_texture().get_image();var after=post_pipeline.ao_scene.get_texture().get_image();var darkened=0;var count=0;var total=0.0
 for y in range(0,before.get_height(),8):
  for x in range(0,before.get_width(),8):
   var a=before.get_pixel(x,y);var b=after.get_pixel(x,y);var la=a.r*.2126+a.g*.7152+a.b*.0722;var lb=b.r*.2126+b.g*.7152+b.b*.0722
   if la>.02:
    count+=1;total+=lb/la
    if lb<la*.98:darkened+=1
 ao_reports.append({"frame":frame,"enabled":post_pipeline.ao_enabled,"ssao_enabled":get_world_3d().environment.ssao_enabled,"minimum_ao":minimum,"darkened_samples":darkened,"mean_luminance_ratio":total/maxi(count,1),"world_samples":post_pipeline.world_samples.samples,"weapon_samples":post_pipeline.weapon_samples.samples,"combined_ready":post_pipeline.combined_depth.is_ready(),"half_ready":post_pipeline.half_depth.is_ready(),"combined_sample":post_pipeline.combined_depth.selected_sample})

func _solar_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:game_flow.start("mission",false,false,true);enemy_manager.clear()
 _game_tick(dt,{})
 var direction=post_pipeline.sun_direction
 var position=Vector3(60,3,25)
 if frame>=121 and frame<=240:position=Vector3(-11,1.68,-23)
 if frame>=241 and frame<=360:direction=direction.rotated(Vector3.UP,float(frame-240)/120*PI)
 elif frame<=120:direction=direction.rotated(Vector3.UP,sin(float(frame)/120*TAU)*.16)
 camera.global_position=position;camera.look_at(position+direction*100,Vector3.UP)
 if frame in [45,100,160,220,280,340,400,460]:_solar_still(frame)
 if frame>=480:
  var failures=[]
  for sample in solar_reports:
   if sample.frame in [45,100,400,460] and sample.visibility<.9:failures.append("clear sun not visible at%d"%sample.frame)
   if sample.frame==220 and sample.visibility>.01:failures.append("interior sun not occluded")
   if sample.frame==340 and sample.sun_on!=0:failures.append("offscreen sun not gated")
  var report={"frames":frame,"failures":failures,"snapshots":solar_reports,"scope":"Actual native source sky and source scene world/weapon depth, originalQ9 visibility smoothing and tk flare gain. Controlled camera at open sea and original warehouse, then rotates away/back. Diagnostic camera movement; not manual gameplay or originalMSAA edge visual parity."}
  var file=FileAccess.open("res://evidence/solar-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"solar_preview_failures":failures}));_dispose_game();get_tree().quit()

func _solar_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/solar-%03d.png"%frame)
 var adapt=post_pipeline.adapt_port.get_texture().get_image().get_pixel(0,0);var projection=post_pipeline.solar_projection
 solar_reports.append({"frame":frame,"camera":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"uv":[projection.uv.x,projection.uv.y],"front":projection.front,"sun_on":post_pipeline.material.get_shader_parameter("uSunOn"),"visibility":adapt.g,"meter":adapt.r,"flare_gain":post_pipeline.material.get_shader_parameter("uFlare"),"world_ready":post_pipeline.world_samples.is_ready(),"weapon_ready":post_pipeline.weapon_samples.is_ready()})

func _status_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==60:game_flow.start("mission",false,false,true);enemy_manager.clear()
 if frame==90:weapon.slots.rifle.ammo=8
 if frame==110:player.damage(75,player.pos+Vector3(5,0,0))
 if frame==150:weapon.reload_now()
 if frame==300:weapon.switch_to("pistol")
 if frame==360:weapon.switch_to("rifle")
 if frame==400:
  var relay=mission.relays[0];player.pos=relay.o.pos+Vector3(0,0,1.8);player.safe_pos=player.pos;player.eye=player.pos+Vector3(0,1.68,0);player.velocity=Vector3.ZERO
  camera.global_position=player.eye;camera.look_at(relay.o.pos+Vector3(0,1.2,0),Vector3.UP);player.yaw=camera.rotation.y;player.pitch=camera.rotation.x;player.forward=(relay.o.pos-player.pos).normalized()
 if frame==580:player.heal(100)
 if frame==600:weapon.slots.rifle.ammo=0;weapon.slots.rifle.reserve=0
 if frame==630:game_flow.retry()
 _game_tick(dt,{"interact":frame>=400 and frame<550,"ads":post_preview and frame>=305 and frame<355})
 if frame in [80,120,170,290,340,430,520,560,620,700] or post_preview and frame==354:_status_still(frame)
 if frame>=720:
  var report={"frames":frame,"snapshots":status_reports,"scope":"Native source-style ammo/health/prompt HUD: controlled ammo initialization, actual reload/switch/damage/heal, teleport near real relay then real held-interact cut, retry clean state; not manual game acceptance"}
  var file=FileAccess.open("res://evidence/status-hud-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
  if post_preview:
   var post_file=FileAccess.open("res://evidence/post-runtime.json",FileAccess.WRITE);post_file.store_string(JSON.stringify(report,"  "));post_file.close()
  _dispose_game();get_tree().quit()

func _status_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/status-%03d.png"%frame)
 var nearest=game_ui.status_hud.prompt
 status_reports.append({"frame":frame,"weapon":weapon.current,"state":weapon.state,"status":game_ui.status_hud.status.duplicate(true),"health_opacity":game_ui.status_hud.health_opacity,"prompt":not nearest.is_empty(),"progress":nearest.get("t",0),"cut":mission.run.cut,"post":{"damage":player.hurt_pulse,"low_health":player.low_health,"ads":player.ads,"manual_exposure":post_pipeline.material.get_shader_parameter("uExposure"),"auto_exposure":post_pipeline.material.get_shader_parameter("uAuto"),"world_depth_ready":post_pipeline.world_samples.is_ready(),"weapon_depth_ready":post_pipeline.weapon_samples.is_ready(),"world_depth_size":[post_pipeline.world_samples.output_size.x,post_pipeline.world_samples.output_size.y],"weapon_depth_size":[post_pipeline.weapon_samples.output_size.x,post_pipeline.weapon_samples.output_size.y]}})

func _sight_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==30:game_flow.start("mission",false,false,true);enemy_manager.clear()
 if frame==320:source_scene.sight_environment_intensity=.3
 if frame==410:source_scene.sight_environment_intensity=1
 _game_tick(dt,{"ads":frame>=120 and frame<470,"fire":frame>=250 and frame<265})
 if frame in [80,200,260,350,450,510]:_sight_still(frame)
 if frame>=540:
  var report={"frames":frame,"sight_materials":source_scene.sight_materials.size(),"snapshots":sight_reports,"pending_shaders":source_scene.report.pending_shaders,"scope":"Native original sight shader on exported source geometry with actual hip/ADS/firing; controlled sight environment intensity transition, full scene indoor/environment adaptation and exact post tone map still pending"}
  var file=FileAccess.open("res://evidence/sight-glass-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()

func _sight_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/sight-%03d.png"%frame)
 sight_reports.append({"frame":frame,"ads":player.ads,"environment":source_scene.sight_environment.value,"camera_fov":camera.fov,"weapon_fov":view_camera.fov})

func _sea_preview_step()->void:
 sea_frame+=1;var frame=sea_frame
 if frame<=160:
  camera.global_position=Vector3(28,4,23)+Vector3(0,0,-float(frame)/160*2);camera.look_at(Vector3(65,-1.6,40),Vector3.UP)
 elif frame<=320:
  camera.global_position=Vector3(34,2,6)+Vector3(0,0,-float(frame-160)/160*3);camera.look_at(Vector3(30,-1.6,3),Vector3.UP)
 else:
  camera.global_position=Vector3(54,2.3,8)+Vector3(0,0,float(frame-320)/160*3);camera.look_at(camera.global_position+Vector3(60,-4,20),Vector3.UP)
 if frame in [60,150,220,300,380,470]:_sea_still(frame)
 if frame>=480:
  var report={"frames":frame,"time":animation_time,"sea_mesh":"b7bbc842-ab5d-46a7-af1b-8e491392b8b7","vertices":13620,"material_time":source_scene.materials["0066994d-de85-4ef1-bc61-07a02c23657f"].get_shader_parameter("uTime"),"shader":source_scene.materials["0066994d-de85-4ef1-bc61-07a02c23657f"].shader.resource_path,"scope":"Native original sea vertex displacement, analytic slopes, original detail textures, foam/scum, wind roughness and haze; Godot PBR/IBL bridge, exact source lighting and post calibration pending"}
  var file=FileAccess.open("res://evidence/sea-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
func _sea_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/sea-%03d.png"%frame)

func _update_rain(dt:float)->void:
 if rain_system!=null:
  rain_system.update(dt,camera.fov,post_pipeline.world_port.size.y if post_pipeline!=null else get_viewport().get_visible_rect().size.y,source_scene.source.modules.level.interiorBoxes,source_scene.source.modules.level.skylights)
  for record in source_scene.source.materials:
   if record.name=="apron_wet":source_scene.materials[record.id].set_shader_parameter("uRain",rain_system.level)

func _rain_preview_step()->void:
 rain_frame+=1;var frame=rain_frame
 if frame<=120:
  camera.global_position=Vector3(-24,1.68,6);camera.look_at(Vector3(10,1,-2),Vector3.UP)
 elif frame<=180:
  camera.global_position=Vector3(-24,.65,6);camera.look_at(Vector3(-19,.05,3),Vector3.UP)
 elif frame<=360:
  camera.global_position=Vector3(-13,1.4,-15);camera.look_at(Vector3(-8,4,-18),Vector3.UP)
 else:
  camera.global_position=Vector3(-2,2,-9);camera.look_at(Vector3(-4,4,-11),Vector3.UP)
 if frame==420:rain_system.set_rain(0)
 if frame in [90,155,240,390,590]:_rain_still(frame)
 if frame>=600:
  var report={"frames":frame,"rain_instances":rain_system.rain.multimesh.instance_count,"splash_instances":rain_system.splash.multimesh.instance_count,"snapshots":rain_reports,"seed_transfer":rain_system.verify_exported_seeds(),"level":rain_system.level,"time":rain_system.time,"scope":"Original exported rain/eave/splash seeds and shaders; native controller/camera wrapping, roof boxes/skylights and rain fade. Global source fork RNG/thunder-to-sky/lens wetness pending."}
  var file=FileAccess.open("res://evidence/rain-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
func _rain_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/rain-%03d.png"%frame)
 rain_reports.append({"frame":frame,"camera":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"level":rain_system.level,"time":rain_system.time,"pixel_width":rain_system.pixel_width,"drip":rain_system.drip})

func _sky_preview_step()->void:
 sky_frame+=1;var frame=sky_frame
 camera.global_position=Vector3(28,4,23)
 camera.look_at(camera.global_position+Vector3(-.5,.5,-.7)*50,Vector3.UP)
 if frame==120:sky_weather.trigger(1,Vector3(1.0/6,.5,.2))
 if frame==300:rain_system.thunder_timer=0
 if frame in [60,121,126,140,180,301,306,360,470]:_sky_still(frame)
 if frame>=480:
  var report={"frames":frame,"time":animation_time,"snapshots":sky_reports,"rain_thunder_events":sky_thunder_events,"scope":"Original analytic dynamic sky in source cube geometry, retained original static PMREM panorama for lighting; controlled thunder triggers and real rain thunder event wiring. Full post thunder and world indoor adaptation pending"}
  var file=FileAccess.open("res://evidence/sky-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();_dispose_game();get_tree().quit()
func _sky_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/sky-%03d.png"%frame)
 sky_reports.append({"frame":frame,"world_time":animation_time,"flash":sky_weather.value,"flash_direction":[sky_weather.direction.x,sky_weather.direction.y,sky_weather.direction.z]})

func _volume_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:game_flow.start("mission",false,false,true);enemy_manager.clear()
 _game_tick(dt,{})
 camera.global_position=Vector3(-11,1.68,-23);camera.look_at(Vector3(5,4,-21),Vector3.UP)
 post_pipeline.volume_enabled=frame>120
 post_pipeline.volume_force_unshadowed=frame>240
 if frame in [100,220,340]:_volume_still(frame)
 if frame>=360:
  var failures=[];var differences=[]
  if volume_reports.size()!=3:failures.append("missing volume snapshots")
  else:
   for index in [1,2]:
    var a:Image=volume_images[index-1];var b:Image=volume_images[index];var changed=0;var total=0.0
    for y in range(0,a.get_height(),4):
     for x in range(0,a.get_width(),4):
      var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);var difference=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
      total+=difference
      if difference>.003:changed+=1
    differences.append({"from":index-1,"to":index,"changed_samples":changed,"sum_rgb_difference":total})
    if changed<10:failures.append("volume stage %d did not visibly change HDR scene"%index)
   if volume_reports[1].minimum_transmittance>=.99:failures.append("no extinction")
   if not volume_reports[1].shadow_ready:failures.append("shadow input not ready")
  var report={"frames":frame,"failures":failures,"snapshots":volume_reports,"differences":differences,"scope":"Frozen native warehouse: first120 volumeoff, next120 original24step shadowedvolume, last120 diagnostic unshadowedvolume. Original4096 shadowinput and RGBA16F scattering/transmittance. Controlled camera, not full gameplay acceptance."}
  var file=FileAccess.open("res://evidence/volume-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"volume_preview_failures":failures}));_dispose_game();get_tree().quit()

func _volume_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/volume-%03d.png"%frame)
 var image=post_pipeline.volume_ports[2].get_texture().get_image();var minimum=1.0;var maximum=0.0
 for y in range(0,image.get_height(),4):
  for x in range(0,image.get_width(),4):
   var pixel=image.get_pixel(x,y);minimum=minf(minimum,pixel.a);maximum=maxf(maximum,maxf(pixel.r,maxf(pixel.g,pixel.b)))
 volume_images.append(post_pipeline.ao_scene.get_texture().get_image())
 volume_reports.append({"frame":frame,"enabled":post_pipeline.volume_enabled,"force_unshadowed":post_pipeline.volume_force_unshadowed,"minimum_transmittance":minimum,"maximum_scattering":maximum,"shadow_ready":sun_shadow_pass.depth.is_ready(),"shadow_resolution":sun_shadow_pass.viewport.size})

func _motion_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:game_flow.start("mission",false,false,true);enemy_manager.clear()
 _game_tick(dt,{})
 var phase=(frame-1)%240
 camera.global_position=Vector3(-11,1.68,-23)
 var direction=Vector3(1,.02,0).rotated(Vector3.UP,sin(float(phase)/240*TAU)*1.0)
 camera.look_at(camera.global_position+direction*20,Vector3.UP)
 post_pipeline.motion_enabled=frame>240
 if frame in [120,360]:_motion_still(frame)
 if frame>=480:
  var failures=[]
  if motion_reports.size()!=2:failures.append("missing motion snapshots")
  else:
   if motion_reports[0].changed_samples>0:failures.append("disabled motion changed scene")
   if motion_reports[1].changed_samples<100:failures.append("enabled motion not contributing")
  var report={"frames":frame,"failures":failures,"snapshots":motion_reports,"scope":"Native repeated camera trajectory, first240 motion off, next240 on, full AO/volume/bloom enabled. Diagnostic trajectory, not full original visual parity."}
  var file=FileAccess.open("res://evidence/motion-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"motion_preview_failures":failures}));_dispose_game();get_tree().quit()

func _motion_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/motion-%03d.png"%frame)
 var before=post_pipeline.ao_scene.get_texture().get_image();var after=post_pipeline.motion_port.get_texture().get_image();var changed=0;var maximum=0.0
 for y in range(0,before.get_height(),4):
  for x in range(0,before.get_width(),4):
   var a=before.get_pixel(x,y);var b=after.get_pixel(x,y);var difference=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,difference)
   if difference>.003:changed+=1
 motion_reports.append({"frame":frame,"enabled":post_pipeline.motion_enabled,"shutter":post_pipeline.motion_material.get_shader_parameter("uShutter"),"changed_samples":changed,"maximum_rgb_difference":maximum})

func _source_sun_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:game_flow.start("mission",false,false,true);enemy_manager.clear()
 _game_tick(dt,{})
 camera.global_position=Vector3(-25,2.5,6);camera.look_at(Vector3(0,1.5,-8),Vector3.UP)
 source_sun_service.radiance_enabled=frame>120;source_sun_service.shadows_enabled=frame<=240
 if frame in [100,220,340]:_source_sun_still(frame)
 if frame>=360:
  var failures=[];var differences=[]
  if source_sun_reports.size()!=3:failures.append("missing source sun snapshots")
  else:
   for index in [1,2]:
    var a:Image=source_sun_images[index-1];var b:Image=source_sun_images[index];var changed=0;var sum=0.0
    for y in range(0,a.get_height(),4):
     for x in range(0,a.get_width(),4):
      var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);var delta=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b);sum+=delta
      if delta>.003:changed+=1
    differences.append({"from":index-1,"to":index,"changed_samples":changed,"sum_rgb_difference":sum})
    if changed<20:failures.append("source sun stage%d not contributing"%index)
   for sample in source_sun_reports:
    if not sample.flag_failures.is_empty():failures.append_array(sample.flag_failures)
  var report={"frames":frame,"failures":failures,"differences":differences,"snapshots":source_sun_reports,"scope":"Frozen actual source scene, first120 source directsunoff (migration retained), next120 originalsun+PCSS, last120 diagnosticreceiveshadowoff. Generic Standard only, other light/IBL and nonmigrated surfaces retained. Original node materialtypes/receiveShadow independently audited, no native sun on migrated objects."}
  var file=FileAccess.open("res://evidence/source-sun-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"source_sun_preview_failures":failures}));_dispose_game();get_tree().quit()

func _source_sun_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/source-sun-%03d.png"%frame)
 source_sun_images.append(post_pipeline.scene_port.get_texture().get_image())
 var material_records={}
 for material_record in source_scene.source.materials:material_records[material_record.id]=material_record
 var failures=[];var expected_count=0;var expected_receivers=0
 for id in source_scene.records:
  var record=source_scene.records[id]
  if not record.has("geometry"):continue
  var eligible=true;var lit=false
  for material_id in record.materials:
   var material_record=material_records[material_id]
   if material_record.type=="MeshStandardMaterial":lit=true
   elif material_record.type!="MeshBasicMaterial":eligible=false
  var expected=eligible and lit;var node:GeometryInstance3D=source_scene.source_nodes[id]
  var active=node.get_instance_shader_parameter("source_sun_active")==true
  if active!=expected:failures.append("migration eligibility "+str(id))
  if expected:
   expected_count+=1
   var receive=bool(record.receiveShadow) and source_sun_service.shadows_enabled
   if (node.get_instance_shader_parameter("source_sun_receive_shadow")==true)!=receive:failures.append("receiveShadow "+str(id))
   if receive:expected_receivers+=1
   if (node.layers&source_sun_service.NATIVE_SUN_LAYER)!=0:failures.append("duplicate native sun "+str(id))
  elif (node.layers&source_sun_service.NATIVE_SUN_LAYER)==0:failures.append("missing native fallback "+str(id))
 if world_sun.light_cull_mask!=source_sun_service.NATIVE_SUN_LAYER:failures.append("native sun mask not isolated")
 source_sun_reports.append({"frame":frame,"radiance_enabled":source_sun_service.radiance_enabled,"shadows_enabled":source_sun_service.shadows_enabled,"shadow_ready":sun_shadow_pass.depth.is_ready(),"service":source_sun_service.report.duplicate(),"expected_migrated_source_nodes":expected_count,"expected_receivers":expected_receivers,"flag_failures":failures})

func _planar_preview_step(dt:float)->void:
 flow_preview_frame+=1;var frame=flow_preview_frame
 if frame==1:
  game_flow.start("mission",false,false,true);enemy_manager.clear()
  planar_trace=preload("res://scripts/render_order_trace.gd").new()
  if planar_reflection.initialized:
   for pair in [[planar_reflection.camera,"reflection"],[sun_shadow_pass.camera,"sun"],[camera,"world"],[view_camera,"weapon"]]:
    var marker=preload("res://scripts/render_order_marker.gd").new();marker.trace=planar_trace;marker.label=pair[1];var effects=pair[0].compositor.compositor_effects;effects.append(marker);pair[0].compositor.compositor_effects=effects
 planar_trace.begin(frame)
 _game_tick(dt,{})
 camera.global_position=Vector3(-25,1.4,6);camera.look_at(Vector3(0,-.1,-8),Vector3.UP)
 planar_reflection.enabled=frame>120
 if frame in [100,221]:_planar_still(frame)
 if frame>=240:
  var failures=[];var changed=0;var sum=0.0
  if planar_reports.size()!=2:failures.append("missing planar snapshots")
  else:
   var a:Image=planar_images[0];var b:Image=planar_images[1]
   for y in range(0,a.get_height(),4):
    for x in range(0,a.get_width(),4):
     var ca=a.get_pixel(x,y);var cb=b.get_pixel(x,y);var difference=absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b);sum+=difference
     if difference>.003:changed+=1
   if changed<20:failures.append("reflection not contributing")
   if not planar_reports[1].capture_ready:failures.append("reflection HDR not ready")
   if planar_reports[1].order.events!=["reflection","sun","world","weapon"]:failures.append("producer callback order differs from original")
   for sample in planar_reports:
    if not sample.layer_failures.is_empty():failures.append_array(sample.layer_failures)
  var report={"engine":Engine.get_version_info(),"frames":frame,"failures":failures,"changed_samples":changed,"sum_rgb_difference":sum,"snapshots":planar_reports,"scope":"Actual original scene frozen yard off/on planar reflection, source oblique/halfresolution/HDRmips/RP, original four excluded nodes, callback order trace. Does not yet prove pertexel previous shadow age, dynamic motion, resize, or complete original image parity."}
  var file=FileAccess.open("res://evidence/planar-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"planar_preview_failures":failures}));_dispose_game();get_tree().quit()

func _planar_still(frame:int)->void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://evidence/planar-%03d.png"%frame);planar_images.append(post_pipeline.scene_port.get_texture().get_image())
 var failures=[];var layer_records=[]
 if planar_reflection.initialized:
  for item in planar_reflection.excluded:
   var node=item.node.get_ref();layer_records.append({"name":item.name,"layers":node.layers})
   if (node.layers&1)!=0 or (node.layers&4)==0:failures.append("reflection exclusion "+item.name)
  planar_reflection.capture.output.get_image().save_png("res://evidence/planar-hdr-%03d.png"%frame)
 if camera.cull_mask!=5 or view_camera.cull_mask!=2:failures.append("main or weapon mask changed")
 planar_reports.append({"frame":frame,"enabled":planar_reflection.enabled,"capture_ready":planar_reflection.initialized and planar_reflection.capture.is_ready(),"pass":planar_reflection.report.duplicate(true),"excluded_layers":layer_records,"layer_failures":failures,"order":planar_trace.snapshot()})

func _cold_enemy_record(record:Dictionary,pool:Array)->Dictionary:
 for template in pool:
  if template.active or int(template.id)!=0:continue
  var fresh=template.duplicate(true);fresh.rig=record.rig;fresh.lens=record.lens
  source_scene.set_source_transform(record.rig.group["$node"],source_scene._transform(source_scene.records[template.rig.group["$node"]].matrix))
  for bone in template.rig.bones:
   source_scene.set_source_transform(record.rig.bones[bone]["$node"],source_scene._transform(source_scene.records[template.rig.bones[bone]["$node"]].matrix))
  source_scene.materials[record.lens["$material"]].set_shader_parameter("base_color",source_scene.materials[template.lens["$material"]].get_shader_parameter("base_color"))
  return fresh
 assert(false,"Original unused enemy pool template missing");return {}
