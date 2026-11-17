extends SceneTree

var game
var boot_loading
var reference:Dictionary
var render_options
var frames=0
var limit=0
var frozen=false
var ready=false
var finishing=false
var capture="res://evidence/level-showcase.png"
var level_nodes:Array=[]
var level_materials:Array=[]
var level_lights=0
var showcase="level"
var backdrop_part="all"
var label_textures=[]

func _initialize()->void:
 render_options=preload("res://scripts/studio_render_options.gd").new(OS.get_cmdline_user_args())
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--level-frames="):limit=int(arg.get_slice("=",1))
  elif arg.begins_with("--level-capture="):capture=arg.trim_prefix("--level-capture=")
  elif arg=="--level-freeze":frozen=true
  elif arg.begins_with("--showcase="):showcase=arg.trim_prefix("--showcase=")
  elif arg.begins_with("--bshow="):backdrop_part=arg.trim_prefix("--bshow=")
 assert(showcase in ["level","backdrop"] and backdrop_part in ["all","crane","ship","boat","sky"],"Invalid scene showcase")
 call_deferred("setup")

func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 var binding_path="level-showcase-bindings.json" if showcase=="level" else "backdrop-"+backdrop_part+"-showcase-bindings.json"
 reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/"+binding_path))
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 preload("res://scripts/weapon_studio_environment.gd").isolate(game)
 game.source_scene.source.modules.level.skylights=[];game.ground_queries.interiors=[];game.ground_queries.metal_rects.clear()
 game.game_flow.state="showcase"
 if showcase=="level":_restore_level(game.source_scene.source_nodes[reference.level_root])
 else:
  var source=game.source_scene
  source.backdrop_showcase=true;source.source.modules.backdrop.boatBase=[24,.34,15];source.backdrop_motion.boat.position=Vector3(24,.34,15)
  for binding in reference.nodes:_restore_level(source.source_nodes[binding.id])
  for extra in reference.extras:
   source.geometry_records[extra.geometry.id]=extra.geometry
   var node=MeshInstance3D.new();node.mesh=source._mesh(extra.geometry.id,{"materials":extra.materials})
   if extra.has("label_texture"):
    var record:Dictionary=extra.label_texture
    var image=Image.create_from_data(int(record.width),int(record.height),true,Image.FORMAT_RGBA8,FileAccess.get_file_as_bytes(record.file))
    var texture=ImageTexture.create_from_image(image);var material=source.materials[extra.materials[0]].duplicate()
    material.set_shader_parameter("albedo_tex",texture);node.set_surface_override_material(0,material)
    var readback=texture.get_image();var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(readback.get_data())
    var digest=hash.finish().hex_encode()
    assert(digest==record.sha256,"Original backdrop label GPU mip hash")
    label_textures.append({"geometry":extra.geometry.id,"width":readback.get_width(),"height":readback.get_height(),"mipmaps":readback.get_mipmap_count(),"sha256":digest})
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;source.add_child(node)
   var m=extra.matrix;node.transform=Transform3D(Basis(Vector3(m[0],m[1],m[2]),Vector3(m[4],m[5],m[6]),Vector3(m[8],m[9],m[10])),Vector3(m[12],m[13],m[14]))
   _restore_level(node)
 var floor=game.source_scene.source_nodes["weapon-studio-concrete-ground"]
 for material in game.source_ibl_service._materials(floor):
  if game.source_ibl_service._supported(material) and material not in level_materials:level_materials.append(material)
 # Begin at the source ready snapshot, including the fan and relay poses already baked there.
 game.animation_time=float(reference.source_time);game.source_scene.update_backdrop_time(game.animation_time)
 game.source_ibl_service.update(0.0)
 for material in level_materials:
  material.set_shader_parameter("source_ibl_explicit_room",false)
 view();ready=true
 if boot_loading!=null:await boot_loading.finish_showcase(game)

func _restore_level(node:Node)->void:
 var id=str(node.get_meta("source_id",""));var record=game.source_scene.records.get(id,{})
 if node is Node3D and not record.is_empty():node.visible=bool(record.visible)
 if node is OmniLight3D:level_lights+=1
 if node is GeometryInstance3D:
  level_nodes.append(node)
  for material in game.source_ibl_service._materials(node):
   if game.source_ibl_service._supported(material) and material not in level_materials:level_materials.append(material)
 for child in node.get_children():_restore_level(child)

func view()->void:
 var c=reference.camera;game.camera.global_position=Vector3(c.position[0],c.position[1],c.position[2]);game.camera.quaternion=Quaternion(c.quaternion[0],c.quaternion[1],c.quaternion[2],c.quaternion[3]);game.camera.fov=c.fov;game.camera.near=c.near;game.camera.far=c.far
 render_options.apply(game);game.camera.make_current();game.view_camera.cull_mask=0;game.game_ui.root.visible=false

func _process(dt:float)->bool:
 if not ready or finishing:return false
 frames+=1;view();game._process(0.0 if frozen else minf(dt,.05));preload("res://scripts/weapon_studio_environment.gd").after_frame(game);view()
 if Input.is_physical_key_pressed(KEY_ESCAPE) or (limit>0 and frames>=limit):finishing=true;call_deferred("finish")
 return false

func finish()->void:
 await process_frame;RenderingServer.force_draw(false)
 var failures=[];var casters=0;var explicit_room=0
 if level_nodes.size()!=reference.nodes.size()+reference.get("extras",[]).size():failures.append("original level mesh count")
 if level_lights!=(4 if showcase=="level" else 0):failures.append("original warehouse lights")
 for binding in reference.nodes:
  var node=game.source_scene.source_nodes[binding.id]
  if node not in level_nodes or not node.is_visible_in_tree():failures.append("level mesh visibility "+binding.id)
  if game.sun_shadow_pass.bindings.has(node.get_instance_id()):casters+=1
 if casters!=int(reference.casters):failures.append("original level shadow casters")
 for material in level_materials:
  if material.get_shader_parameter("source_ibl_explicit_room"):explicit_room+=1
 if explicit_room!=0 or game.source_ibl_service.view_room:failures.append("showcase inherited Main interior environment")
 if not frozen and frames>1 and game.source_scene.backdrop_time<=float(reference.source_time):failures.append("live level animation did not advance")
 if showcase=="backdrop":
  var boat=game.source_scene.backdrop_motion.boat
  if not boat.position.is_equal_approx(Vector3(24,.34,15)):failures.append("showcase boat fixed base")
 if game.planar_reflection.enabled or game.rain_system.rain.visible or game.rain_system.splash.visible:failures.append("stub showcase ground/backdrop replaced")
 root.get_texture().get_image().save_png(capture)
 var hdr=game.post_pipeline.world_port.get_texture().get_image();hdr.flip_y();var hdr_path=capture.trim_suffix(".png")+".rgb16f";FileAccess.open(hdr_path,FileAccess.WRITE).store_buffer(hdr.get_data())
 var report={"frames":frames,"frozen":frozen,"world_time":game.animation_time,"motion_time":game.source_scene.backdrop_time,"nodes":level_nodes.size(),"warehouse_lights":level_lights,"shadow_casters":casters,"explicit_room_materials":explicit_room,"render_options":render_options.report(game),"hdr":{"file":hdr_path,"format":hdr.get_format(),"width":hdr.get_width(),"height":hdr.get_height(),"row_order":"top-to-bottom"},"failures":failures,"showcase":showcase,"backdrop_part":backdrop_part,"scope":"Original scene showcase geometry, common80m concrete floor, stub environment and live source animation. No whole-image parity or original texture hash claim."}
 report.label_textures=label_textures
 FileAccess.open(capture.trim_suffix(".png")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
