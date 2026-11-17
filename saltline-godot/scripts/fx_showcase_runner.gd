extends SceneTree
# Standalone source FX showcase entry point. No gameplay or audio.
var game
var boot_loading
var showcase
var mode="all"
var params={}
var frame=0
var limit=0
var fixed=false
var frozen=false
var capture_path=""
var tape_path=""
var state_path="res://evidence/fx-showcase-native-state.json"
var fx_rng
var snapshot_draws=-1
var finished=false
var setup_ready=false
var render_warmup=0
var manual_exposure=-1.0
var soft_particles=true
var hide_particles=false
var no_point_lights=false
var surface_debug=""
var noise_mode="production"
var exposure_trace=[]
var tracing_exposure=false
var awaiting_draw=false
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--fx-tape="):tape_path=arg.trim_prefix("--fx-tape=")
  elif arg.begins_with("--fx-noise="):noise_mode=arg.get_slice("=",1)
  elif arg.begins_with("--fx-surface="):surface_debug=arg.get_slice("=",1)
  elif arg=="--fx-no-point-lights":no_point_lights=true
  elif arg=="--fx-hide-particles":hide_particles=true
  elif arg=="--fx-soft=0":soft_particles=false
  elif arg.begins_with("--fx-state="):state_path=arg.trim_prefix("--fx-state=")
  elif arg.begins_with("--fx-mode="):mode=arg.get_slice("=",1)
  elif arg.begins_with("--fx-hold="):params.fxhold=arg.get_slice("=",1)
  elif arg.begins_with("--fx-size="):params.fxsize=float(arg.get_slice("=",1))
  elif arg.begins_with("--fx-prewarm="):params.fxt=float(arg.get_slice("=",1))
  elif arg.begins_with("--fx-age="):params.fxage=float(arg.get_slice("=",1))
  elif arg.begins_with("--fx-manual-exposure="):manual_exposure=float(arg.get_slice("=",1))
  elif arg.begins_with("--fx-render-warmup="):render_warmup=maxi(0,int(arg.get_slice("=",1)))
  elif arg.begins_with("--fx-frames="):limit=int(arg.get_slice("=",1))
  elif arg.begins_with("--fx-capture="):capture_path=arg.trim_prefix("--fx-capture=")
  elif arg=="--fx-fixed":fixed=true
 call_deferred("setup")
func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path="";game.showcase_render=true
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 game.impact_effects.ground_queries=null
 var geometry=preload("res://scripts/fx_showcase_geometry.gd").isolate(game.source_scene,game.player.physics);game.source_scene.add_child(geometry)
 if surface_debug in ["albedo","normal","roughness","direct-diffuse","direct-specular","indirect-diffuse","indirect-specular","orm","normal-length","macro"]:_debug_surfaces(geometry)
 if not tape_path.is_empty():
  fx_rng=preload("res://scripts/fx_random.gd").new(JSON.parse_string(FileAccess.get_file_as_string(tape_path)))
  game.impact_effects.rng=fx_rng;game.impact_effects.pool.rng=fx_rng;game.impact_effects.lit_pool.rng=fx_rng;game.impact_effects.debris.rng=fx_rng;game.explosion_effects.rng=fx_rng;game.decals.rng=fx_rng;game.shells.rng=fx_rng;game.tracers.rng=fx_rng
 showcase=preload("res://scripts/fx_showcase.gd").new(game,mode,params)
 _view()
 _freeze_viewports(game)
 await process_frame
 for batch in [game.impact_effects.lit_batch,game.impact_effects.batch]:batch.material.set_shader_parameter("soft_particles",soft_particles)
 tracing_exposure=true;RenderingServer.frame_post_draw.connect(_trace_exposure)
 if manual_exposure>=0:
  game.post_pipeline.set_auto_exposure(false)
  for material in [game.post_pipeline.material,game.post_pipeline.ao_material]+game.post_pipeline.streak_materials:material.set_shader_parameter("uExposure",manual_exposure)
 var t=0.0
 while t<float(params.get("fxt",0)):
  showcase.update(1.0/30);game._advance_effects(1.0/30);t+=1.0/30
 for i in render_warmup:
  showcase.update(1.0/60);game._advance_effects(1.0/60);_view();game._process(1.0/60);_view()
  _render_once()
  await process_frame
 if params.has("fxage"):
  game.explosion_effects.clear();game.impact_effects.lit_pool.clear();game.impact_effects.pool.clear();game.tracers.clear();game.shells.clear()
  game.explosion_effects.explode(Vector3(0,.25,3.5),float(params.get("fxsize",1.2)) if float(params.get("fxsize",1.2))!=0 else 1.2)
  t=0
  while t<float(params.fxage)-.000001:game._advance_effects(1.0/60);t+=1.0/60
  game._advance_effects(0);frozen=true
  if fx_rng!=null:snapshot_draws=fx_rng.calls
 if no_point_lights:
  for slot in game.light_pool.slots:slot.peak=0;game.light_pool.set_energy(slot,0)
 setup_ready=true
 if boot_loading!=null:await boot_loading.finish_showcase(game)
func _view()->void:
 game.camera.fov=74;game.camera.near=.08;game.camera.far=900
 game.camera.global_position=Vector3(0,2,12.5) if mode=="explosion" else Vector3(.3,1.6,7.2)
 game.camera.look_at(Vector3(0,2.2,3.5) if mode=="explosion" else Vector3(.2,1,0));game.camera.make_current();game.view_camera.cull_mask=0;game.game_ui.root.visible=false
 if hide_particles:
  game.impact_effects.lit_batch.geometry.visible=false;game.impact_effects.batch.geometry.visible=false
 for record in game.source_scene.source.nodes:
  if record.name in ["rain","rainSplash"]:game.source_scene.source_nodes[record.id].visible=false
func _process(dt:float)->bool:
 if not setup_ready or awaiting_draw or game==null or showcase==null or finished:return false
 if Input.is_physical_key_pressed(KEY_ESCAPE):finished=true;call_deferred("finish");return false
 var step=1.0/60 if fixed else minf(dt,.05)
 frame+=1;awaiting_draw=true
 if not frozen:showcase.update(step);game._advance_effects(step)
 _view();game._process(step);_view();_render_once()
 if limit>0 and frame>=limit:finished=true;call_deferred("finish")
 return false
func finish()->void:
 tracing_exposure=false
 _freeze_viewports(game)
 RenderingServer.force_draw(false)
 if not capture_path.is_empty():root.get_texture().get_image().save_png(capture_path)
 var lights=[]
 for slot in game.light_pool.slots:lights.append({"busy":slot.busy,"ttl":slot.ttl,"intensity":slot.source_intensity,"color":[slot.light.light_color.r,slot.light.light_color.g,slot.light.light_color.b],"linear_radiance":[slot.light.light_color.srgb_to_linear().r*slot.source_intensity,slot.light.light_color.srgb_to_linear().g*slot.source_intensity,slot.light.light_color.srgb_to_linear().b*slot.source_intensity]})
 var surfaces=[]
 var geometry=game.source_scene.get_node("SourceFXShowcase")
 for node in geometry.get_children():
  var material=node.material_override if node.material_override!=null else node.mesh.surface_get_material(0)
  var values={}
  for key in ["base_color","roughness_value","metallic_value","wetness","wet_params","macro_params","source_uv_scale","interior","source_ibl_ready","source_ibl_explicit_room","source_ibl_explicit_intensity","source_ibl_view_fill","source_ibl_view_room","source_local_ready","source_sun_ready"]:
   var value=material.get_shader_parameter(key)
   if value is Vector3:value=[value.x,value.y,value.z]
   elif value is Vector2:value=[value.x,value.y]
   elif value is Vector4:value=[value.x,value.y,value.z,value.w]
   values[key]=value
  surfaces.append({"name":node.name,"uniforms":values,"sun_active":node.get_instance_shader_parameter("source_sun_active"),"local_active":node.get_instance_shader_parameter("source_local_active")})
 var quad_data={"fx_lit":[],"fx_add":[]}
 for pair in [["fx_lit",game.impact_effects.lit_pool.quads],["fx_add",game.impact_effects.pool.quads]]:
  for quad in pair[1]:quad_data[pair[0]].append(Array(PackedFloat32Array(quad)))
 var registered_casters=0
 for node in geometry.get_children():
  if game.sun_shadow_pass.bindings.has(node.get_instance_id()):registered_casters+=1
 var report={"world_anisotropy_level":game.post_pipeline.world_port.anisotropic_filtering_level,"surface_debug":surface_debug,"no_point_lights":no_point_lights,"hide_particles":hide_particles,"solar_shadow_size":[game.sun_shadow_pass.viewport.size.x,game.sun_shadow_pass.viewport.size.y],"solar_shadow_config":game.sun_shadow_pass.config,"showcase_shadow_casters":registered_casters,"soft_particles":soft_particles,"snapshot_age":params.get("fxage"),"snapshot_size":params.get("fxsize"),"exposure_trace":exposure_trace,"quads":quad_data,"fx_clock":game.impact_effects.clock,"manual_exposure":manual_exposure,"world_time":game.animation_time,"render_warmup":render_warmup,"surfaces":surfaces,"exposure":game.post_pipeline.material.get_shader_parameter("uExposure"),"auto_exposure":game.post_pipeline.auto_enabled,"lights":lights,"fov":game.camera.fov,"snapshot_draws":snapshot_draws,"lit":game.impact_effects.lit_pool.particles.size(),"add":game.impact_effects.pool.particles.size(),"mode":mode,"frames":frame,"frozen":frozen,"impacts":game.impact_effects.impacts,"explosions":game.explosion_effects.count,"shells":game.shells.emitted,"scope":"Standalone native showcase runtime; source rendering parity remains under investigation."}
 if not capture_path.is_empty():report.capture={"path":capture_path,"sha256":FileAccess.get_sha256(capture_path)}
 var hdr=game.post_pipeline.world_port.get_texture().get_image()
 hdr.flip_y()
 var hdr_path=state_path.trim_suffix(".json")+".world.bin"
 FileAccess.open(hdr_path,FileAccess.WRITE).store_buffer(hdr.get_data())
 report.noise_shader_sha256=FileAccess.get_sha256("res://shaders/source_material_noise.gdshaderinc")
 report.noise_mode=noise_mode
 report.hdr_world={"file":hdr_path,"width":hdr.get_width(),"height":hdr.get_height(),"format":hdr.get_format(),"origin":"top-left","bytes":hdr.get_data().size(),"sha256":FileAccess.get_sha256(hdr_path)}
 FileAccess.open(state_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));var summary=report.duplicate();summary.erase("quads");summary.erase("surfaces");summary.erase("solar_shadow_config");print(JSON.stringify(summary))
 game.explosion_effects.clear();game._dispose_game();game.queue_free();await process_frame;quit()

func _freeze_viewports(node:Node)->void:
 if node is SubViewport:node.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for child in node.get_children():_freeze_viewports(child)

func _trace_exposure()->void:
 awaiting_draw=false
 if not tracing_exposure:return
 var pipeline=game.post_pipeline
 var image=pipeline.adapt_port.get_texture().get_image()
 var history=pipeline.history_port.get_texture().get_image()
 if image.is_empty() or history.is_empty():return
 var current=image.get_pixel(0,0);var previous=history.get_pixel(0,0)
 exposure_trace.append({"frame":frame,"warmup":not setup_ready,"tick_count":pipeline.adapt_frames,"rate":pipeline.adapt_material.get_shader_parameter("uRate"),"visRate":pipeline.adapt_material.get_shader_parameter("uVisRate"),"output":[current.r,current.g,current.b,current.a],"history":[previous.r,previous.g,previous.b,previous.a]})

func _render_once()->void:
 _set_once(game)
 RenderingServer.force_draw(false)
func _set_once(node:Node)->void:
 if node is SubViewport:node.render_target_update_mode=SubViewport.UPDATE_ONCE
 for child in node.get_children():_set_once(child)

func _debug_surfaces(group:Node3D)->void:
 for node in group.get_children():
  var material=node.material_override if node.material_override!=null else node.mesh.surface_get_material(0)
  var shader=Shader.new();var code=material.shader.code
  if noise_mode in ["plain","affine-free","tail-free","fused"]:
   var noise=FileAccess.get_file_as_string("res://shaders/source_material_noise.gdshaderinc")
   noise=noise.replace("sourceNoiseRound3(fma(p,vec3(.3183099),vec3(.71,.113,.419)))","sourceNoiseRound3(sourceNoiseRound3(p*.3183099)+vec3(.71,.113,.419))")
   var tail=noise.substr(noise.find("float slN3("))
   var replacement="float slH(vec3 p){p=fract(p*.3183099+vec3(.71,.113,.419));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}\n"+tail
   if noise_mode=="affine-free":replacement=noise.replace("sourceNoiseRound3(sourceNoiseRound3(p*.3183099)+vec3(.71,.113,.419))","sourceNoiseRound3(p*.3183099+vec3(.71,.113,.419))")
   elif noise_mode=="fused":replacement=noise.replace("sourceNoiseRound3(sourceNoiseRound3(p*.3183099)+vec3(.71,.113,.419))","sourceNoiseRound3(fma(p,vec3(.3183099),vec3(.71,.113,.419)))")
   elif noise_mode=="tail-free":replacement=noise.substr(0,noise.find("float slH("))+"float slH(vec3 p){p=sourceNoiseRound3(p);p=fract(sourceNoiseRound3(sourceNoiseRound3(p*.3183099)+vec3(.71,.113,.419)));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}\n"+tail
   code=code.replace('#include "res://shaders/source_material_noise.gdshaderinc"',replacement)
  code=code.replace("void fragment(){", "void fragment(){vec3 diagnostic_direct_diffuse=vec3(0),diagnostic_direct_specular=vec3(0),diagnostic_indirect_diffuse=vec3(0),diagnostic_indirect_specular=vec3(0);")
  code=code.replace("EMISSION+=detail_diffuse*source_weapon_occlusion+detail_specular*(source_weapon_occlusion*source_weapon_occlusion);", "diagnostic_indirect_diffuse=detail_diffuse*source_weapon_occlusion;diagnostic_indirect_specular=detail_specular*(source_weapon_occlusion*source_weapon_occlusion);")
  code=code.replace("EMISSION+=detail_diffuse*mix(1.0,source_weapon_occlusion,.35)+detail_specular*mix(1.0,source_weapon_occlusion,.6);", "diagnostic_direct_diffuse=detail_diffuse*mix(1.0,source_weapon_occlusion,.35);diagnostic_direct_specular=detail_specular*mix(1.0,source_weapon_occlusion,.6);")
  var end=code.rfind("}")
  var output="ALBEDO" if surface_debug=="albedo" else "normalize(NORMAL)*.5+.5" if surface_debug=="normal" else "vec3(clamp(rr,.045,1.0))"
  if surface_debug=="orm":output="orm.rgb"
  elif surface_debug=="normal-length":output="vec3(length(sourceFetchNormal(uv).xyz*2.0-1.0))"
  elif surface_debug=="macro":output="vec3(mac,mac2,wet)"
  if surface_debug.begins_with("direct-") or surface_debug.begins_with("indirect-"):output="diagnostic_"+surface_debug.replace("-","_")
  code=code.substr(0,end)+"vec3 diagnostic="+output+";ALBEDO=vec3(0);METALLIC=0.;SPECULAR=0.;ROUGHNESS=1.;IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);EMISSION=diagnostic;"+code.substr(end)
  shader.code=code;shader.set_meta("source_shader_path","res://shaders/source_material.gdshader");material.shader=shader
