extends SceneTree
var game
var boot_loading
var catalog
var frames=0
var limit=0
var capture="res://evidence/material-catalog.png"
var config={}
var catalog_path="res://assets/catalog/materials/catalog.json"
var prefix="material-catalog"
var finishing=false
var selected_names=""
var selected_only=""
var wet_override:Variant=null
var wet_materials=0
var asset_quality="high"
var case_label=""
var render_options
func _initialize()->void:
 render_options=preload("res://scripts/studio_render_options.gd").new(OS.get_cmdline_user_args())
 for arg in OS.get_cmdline_user_args():
  if arg=="--catalog=props":catalog_path="res://assets/catalog/props/catalog.json";prefix="prop-catalog";capture="res://evidence/prop-catalog.png"
  elif arg=="--catalog=full":catalog_path="res://assets/catalog/materials-full/catalog.json";prefix="material-catalog-full";capture="res://evidence/material-catalog-full.png"
  elif arg=="--catalog=render":catalog_path="res://assets/catalog/render/catalog.json";prefix="render-catalog";capture="res://evidence/render-catalog.png"
  elif arg=="--catalog=ground":catalog_path="res://assets/catalog/ground/catalog.json";prefix="ground-catalog";capture="res://evidence/ground-catalog.png"
  elif arg.begins_with("--asset-quality="):
   asset_quality=arg.trim_prefix("--asset-quality=")
   if asset_quality not in ["low","medium","high","ultra"]:push_error("Invalid cold-start asset quality");quit(1);return
  elif arg.begins_with("--names="):selected_names=arg.trim_prefix("--names=")
  elif arg.begins_with("--only="):selected_only=arg.trim_prefix("--only=")
  elif arg.begins_with("--wet="):
   var value=arg.trim_prefix("--wet=")
   if not value.is_valid_float() or not is_finite(float(value)):push_error("Expected finite --wet value");quit(1);return
   wet_override=float(value)
  elif arg.begins_with("--catalog-case="):
   case_label=arg.trim_prefix("--catalog-case=")
   var valid=RegEx.new();valid.compile("^[a-z0-9-]+$")
   if valid.search(case_label)==null:push_error("Invalid catalog case label");quit(1);return
  elif arg.begins_with("--catalog-frames="):limit=int(arg.get_slice("=",1))
 if not selected_names.is_empty():catalog_path="res://assets/catalog/props/catalog.json";prefix="prop-catalog"
 elif not selected_only.is_empty():catalog_path="res://assets/catalog/materials-full/catalog.json";prefix="material-catalog-full"
 if asset_quality!="high":
  catalog_path=catalog_path.replace("/catalog.json","-"+asset_quality+"/catalog.json");prefix+="-"+asset_quality;capture="res://evidence/"+prefix+".png"
 if not FileAccess.file_exists(catalog_path):push_error("Missing cold-start catalog assets: "+catalog_path);quit(1);return
 call_deferred("setup")
func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 config=JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
 if not selected_names.is_empty():config=preload("res://scripts/catalog_selection.gd").props(config,Array(selected_names.split(",")),JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog/prop-definitions.json")))
 elif not selected_only.is_empty():config=preload("res://scripts/catalog_selection.gd").materials(config,Array(selected_only.split(",",false)))
 if config.has("error"):push_error(config.error);quit(1);return
 if not selected_names.is_empty() or not selected_only.is_empty():prefix+="-selection";capture="res://evidence/"+prefix+".png"
 if not case_label.is_empty():prefix+="-"+case_label;capture="res://evidence/"+prefix+".png"
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 if config.get("kind","") in ["render","ground"]:
  game.source_scene.source.modules.level.interiorBoxes=[];game.source_scene.source.modules.level.skylights=[];game.player.physics.boxes.clear()
  game.ground_queries.interiors=[];game.ground_queries.metal_rects.clear()
  if config.kind=="render":
   game.planar_reflection.enabled=false;game.rain_system.level=0;game.rain_system.target=0;game.rain_system.thunder_timer=INF
  else:
   var first_fork=preload("res://scripts/source_rng.gd").new(int(game.source_bootstrap.bootstrap_data.streams.level.seed))
   game.rain_system=SaltlineRain.new(game.source_scene,first_fork);game.rain_system.thunder.connect(game.sky_weather.trigger)
  for slot in game.light_pool.slots:game.light_pool.release(slot)
 for id in game.source_scene.source_nodes:
  var node=game.source_scene.source_nodes[id]
  var record=game.source_scene.records.get(id,{})
  var keep_ground=config.get("kind","")=="ground" and game.source_scene.records.get(str(record.get("parent","")),{}).get("name","")=="ground"
  if (node is GeometryInstance3D or node is OmniLight3D) and record.get("name","")!="sky" and not keep_ground:node.visible=false
 catalog=preload("res://scripts/material_catalog.gd").attach(game.source_scene,catalog_path,config)
 if wet_override!=null:wet_materials=preload("res://scripts/material_catalog.gd").set_wet(catalog,float(wet_override))
 for record in config.materials:game.sun_shadow_pass.material_records[record.id]=record
 view()
 if boot_loading!=null:await boot_loading.finish_showcase(game)
func view()->void:
 var c=config.camera;game.camera.global_position=Vector3(c.position[0],c.position[1],c.position[2]);game.camera.quaternion=Quaternion(c.quaternion[0],c.quaternion[1],c.quaternion[2],c.quaternion[3]);game.camera.fov=c.fov;game.camera.near=c.near;game.camera.far=c.far;game.camera.make_current();game.view_camera.cull_mask=0;game.game_ui.root.visible=false
 if config.get("kind","") in ["render","ground"]:
  render_options.apply(game)
  game.source_ibl_service.view_fill=1.1;game.source_ibl_service.update(0.0)
 if config.get("kind","")=="render":
  var height=float(render_options.camera_values[1]) if render_options.camera_values.size()==6 else float(c.position[1])
  var mode=int(floorf(height*1000.0+.5))%10
  for entry in [["uDamage",1,.8],["uLowHealth",2,.85],["uAds",3,1.0],["uFlash",4,.35],["uFade",5,.5]]:game.post_pipeline.material.set_shader_parameter(entry[0],entry[2] if mode==entry[1] else 0.0)
 for record in game.source_scene.source.nodes:
  if config.get("kind","")!="ground" and record.name in ["rain","rainSplash"]:game.source_scene.source_nodes[record.id].visible=false
func _process(_dt:float)->bool:
 if catalog==null or finishing:return false
 frames+=1;view();game._process(1.0/60);view()
 if Input.is_physical_key_pressed(KEY_ESCAPE) or (limit>0 and frames>=limit):finishing=true;call_deferred("finish")
 return false
func finish()->void:
 await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(capture)
 var failures=[];var names=[];var prop_names=[];var ready=0;var casters=0;var texture_checks=0;var expected_lit=0;var expected_casters=0
 var material_types={}
 for record in config.materials:material_types[record.id]=record.type
 for record in config.nodes:
  expected_casters+=int(record.castShadow)
  expected_lit+=int(material_types[record.material] in ["MeshStandardMaterial","MeshPhysicalMaterial"])
 for record in config.textures:
  var texture=game.source_scene._texture({"$texture":record.id},true)
  var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(texture.get_image().get_data())
  texture_checks+=1
  if context.finish().hex_encode()!=record.source_sha256:failures.append("GPU mip bytes "+record.id)
 for node in catalog.get_children():
  var lit=false
  for material in game.source_ibl_service._materials(node):
   if material.get_shader_parameter("source_ibl_ready"):lit=true
  if lit and node.get_instance_shader_parameter("source_sun_active"):ready+=1
  var prop=str(node.get_meta("catalog_prop",""))
  if not prop.is_empty() and prop!="<null>" and prop not in prop_names:prop_names.append(prop)
  var name=str(node.get_meta("catalog_material"))
  if name not in names:names.append(name)
  if game.sun_shadow_pass.bindings.has(node.get_instance_id()):casters+=1
 if catalog.get_child_count()!=config.nodes.size():failures.append("original catalog mesh count")
 if ready!=expected_lit:failures.append("catalog source lighting bindings")
 if casters!=expected_casters:failures.append("catalog source shadow casters")
 for requested in config.requested:
  if requested not in (prop_names if config.get("kind","")=="props" else names):failures.append("missing "+requested)
 var color_checks=0
 var geometry_records={}
 for geometry in config.geometries:geometry_records[geometry.id]=geometry
 for record in config.nodes:
  var geometry=geometry_records[record.geometry]
  if not geometry.attributes.has("color"):continue
  var node=game.source_scene.source_nodes[record.id]
  var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
  var actual=mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM3]
  var bytes:PackedByteArray=actual if actual is PackedByteArray else actual.to_byte_array()
  var expected=PackedFloat32Array();var raw=geometry.attributes.color;var size=int(geometry.attribute_sizes.color)
  for i in range(0,raw.size(),size):expected.append_array(PackedFloat32Array([raw[i],raw[i+1],raw[i+2],raw[i+3] if size==4 else 1.0]))
  color_checks+=1
  if bytes!=expected.to_byte_array():failures.append("source vertex color bytes "+record.id)
 var report={"cold_start_asset_quality":asset_quality,"frames":frames,"wet_override":wet_override,"wet_materials":wet_materials,"nodes":catalog.get_child_count(),"materials":config.materials.size(),"textures":config.textures.size(),"lighting_ready":ready,"shadow_casters":casters,"gpu_texture_hash_checks":texture_checks,"vertex_color_mesh_checks":color_checks,"names":names,"prop_names":prop_names,"failures":failures,"scope":"Original catalog materials, original mesh geometry/transforms and raw GPU mipchains in actual Main lighting. Full original pixel parity, query filtering and generated option variants remain open."}
 if config.get("kind","") in ["render","ground"]:report.render_options=render_options.report(game)
 if config.get("kind","")=="render":
  report.render_post={}
  for parameter in ["uDamage","uLowHealth","uAds","uFlash","uFade"]:report.render_post[parameter]=game.post_pipeline.material.get_shader_parameter(parameter)
 if config.get("kind","")=="ground":
  report.rain_seed_hashes={}
  for entry in [["rain",game.rain_system.rain],["splash",game.rain_system.splash]]:
   var multi:MultiMesh=entry[1].multimesh;var values=PackedFloat32Array()
   for index in multi.instance_count:
    var value=multi.get_instance_custom_data(index);values.append_array(PackedFloat32Array([value.r,value.g,value.b,value.a]))
   var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(values.to_byte_array());var checksum=context.finish().hex_encode();report.rain_seed_hashes[entry[0]]=checksum
   if multi.instance_count!=int(config.ground_reference[entry[0]].count) or checksum!=config.ground_reference[entry[0]].sha256:failures.append("original ground seed "+entry[0])
  report.stub_interiors=game.source_scene.source.modules.level.interiorBoxes.size();report.skylight_openings=game.source_scene.source.modules.level.skylights.size();report.skylight_slots=game.rain_system.skylights.size();report.rain_drip=game.rain_system.drip;report.planar_ready=game.planar_reflection.capture.is_ready();report.rain_time=game.rain_system.time;report.rain_seed=game.rain_system.rng.seed
 FileAccess.open("res://evidence/"+prefix+"-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
