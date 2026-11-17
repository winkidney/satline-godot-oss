extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var case_name=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--paired-case="):case_name=arg.trim_prefix("--paired-case=")
 var tag="high"+("-"+case_name if not case_name.is_empty() else "")
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/main-paired-"+tag+"-source.json"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var c=reference.camera
 game.camera.global_position=Vector3(c.position[0],c.position[1],c.position[2]);game.camera.quaternion=Quaternion(c.quaternion[0],c.quaternion[1],c.quaternion[2],c.quaternion[3]);game.camera.fov=c.fov;game.camera.near=c.near;game.camera.far=c.far
 if not str(reference.get("surface_diagnostic","")).is_empty():
  for record in game.source_scene.source.materials:
   if record.name!="corrugated_roof":continue
   var material=game.source_scene.materials[record.id];var original=material.shader;var code=original.code
   code=code.replace("void fragment(){","void fragment(){vec3 diagnostic_direct=vec3(0),diagnostic_indirect=vec3(0);")
   code=code.replace("EMISSION+=detail_diffuse*source_weapon_occlusion+detail_specular*(source_weapon_occlusion*source_weapon_occlusion);","diagnostic_indirect=detail_specular*(source_weapon_occlusion*source_weapon_occlusion);")
   code=code.replace("EMISSION+=detail_diffuse*mix(1.0,source_weapon_occlusion,.35)+detail_specular*mix(1.0,source_weapon_occlusion,.6);","diagnostic_direct=detail_specular*mix(1.0,source_weapon_occlusion,.6);")
   var mode=reference.surface_diagnostic;var output="normalize(NORMAL)*.5+.5" if mode=="normal" else "vec3(clamp(rr,.045,1.0))" if mode=="roughness" else "diagnostic_direct" if mode=="direct-specular" else "diagnostic_indirect"
   var end=code.rfind("}");code=code.substr(0,end)+"ALBEDO=vec3(0);METALLIC=0.;SPECULAR=0.;ROUGHNESS=1.;IRRADIANCE=vec4(0,0,0,1);RADIANCE=vec4(0,0,0,1);EMISSION="+output+";"+code.substr(end)
   var shader=Shader.new();shader.code=code;shader.set_meta("source_shader_path",original.get_meta("source_shader_path",original.resource_path));material.shader=shader
 game.game_ui.root.visible=false;game.view_camera.cull_mask=0;game.game_flow.fade=0
 game.post_pipeline.set_auto_exposure(false);game.post_pipeline.material.set_shader_parameter("uExposure",1.0);game.post_pipeline.ao_material.set_shader_parameter("uExposure",1.0)
 if reference.has("view_fill"):game.source_ibl_service.view_fill=float(reference.view_fill)
 game.source_local_light_service.radiance_enabled=not bool(reference.get("no_points",false))
 game.source_sun_service.radiance_enabled=not bool(reference.get("no_sun",false))
 var matched_pool=0
 if "--match-source-pool" in OS.get_cmdline_user_args():
  var points=[]
  for light in reference.lights:
   if light.type=="PointLight":points.append(light)
  for i in 6:
   var source=points[i];var slot=game.light_pool.slots[i]
   slot.busy=true;slot.persistent=true
   slot.light.global_position=Vector3(source.position[0],source.position[1],source.position[2]);slot.light.light_color=Color(source.color[0],source.color[1],source.color[2]).linear_to_srgb();slot.light.omni_range=source.distance;slot.light.omni_attenuation=source.decay
   game.light_pool.set_energy(slot,float(source.intensity));matched_pool+=1
 game.animation_time=reference.time.t;game.source_scene.update_backdrop_time(reference.time.t);game.rain_system.time=reference.time.t
 for frame in 12:
  game._process(0.0);game.view_camera.cull_mask=0
  await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/main-paired-"+tag+"-native.png")
 var hdr=game.post_pipeline.world_port.get_texture().get_image()
 hdr.flip_y()
 assert(hdr.get_format()==Image.FORMAT_RGBH,"Expected native HDR RGB half-float readback")
 FileAccess.open("res://evidence/main-paired-"+tag+"-native.world.rgb16f",FileAccess.WRITE).store_buffer(hdr.get_data())
 var report={"matched_snapshot_pool_slots":matched_pool,"hdr":{"width":hdr.get_width(),"height":hdr.get_height(),"format":hdr.get_format(),"channels":3,"dtype":"float16","file":"main-paired-"+tag+"-native.world.rgb16f","row_order":"top-to-bottom"},"surface_diagnostic":reference.get("surface_diagnostic",""),"time":game.animation_time,"backdrop_time":game.source_scene.backdrop_time,"rain_time":game.rain_system.time,"fade":game.game_flow.fade,"exposure":game.post_pipeline.material.get_shader_parameter("uExposure"),"auto":game.post_pipeline.material.get_shader_parameter("uAuto"),"camera_position":[game.camera.position.x,game.camera.position.y,game.camera.position.z],"camera_quaternion":[game.camera.quaternion.x,game.camera.quaternion.y,game.camera.quaternion.z,game.camera.quaternion.w],"scope":"Actual Main fixed source camera/time, manual exposure1, title fade0, HUD/weapon hidden,12 zero-dt GPU warmup renders. No whole-frame parity claim."}
 FileAccess.open("res://evidence/main-paired-"+tag+"-native.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit()
