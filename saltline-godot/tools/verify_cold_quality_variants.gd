extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var quality=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--cold-quality="):quality=arg.trim_prefix("--cold-quality=")
 if quality not in ["medium","ultra"]:quit(2);return
 var original=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/original-"+quality+"-material-bindings-local-fonts.json"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var failures=[];var checked={};var uv_checks=0
 var records={}
 for record in game.source_scene.source.textures:records[record.id]=record
 for binding in original.bindings:
  if not checked.has(binding.original_id):
   var texture=game.source_scene._texture({"$texture":binding.original_id},true)
   var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(texture.get_image().get_data())
   if hash.finish().hex_encode()!=binding.observed_sha256:failures.append("GPU texture "+binding.original_id)
   checked[binding.original_id]=true
  if binding.has("uv"):
   var material=game.source_scene.materials[binding.material]
   if material.get_shader_parameter("tri_scale")!=binding.uv[2] or material.get_shader_parameter("source_uv_scale")!=Vector2(binding.uv[0],binding.uv[1]):failures.append("UV "+binding.material)
   uv_checks+=1
 var reference={}
 for case in JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/rain-initialization.json")).cases:
  if case.quality==quality:reference=case
 var rain=game.rain_system;var rain_components=0
 for entry in [[rain.rain,"rain"],[rain.splash,"splash"]]:
  var expected=FileAccess.get_file_as_bytes("res://assets/export/"+reference.files[entry[1]]).to_float32_array()
  if entry[0].multimesh.instance_count*4!=expected.size():failures.append("rain count")
  for i in entry[0].multimesh.instance_count:
   var actual=entry[0].multimesh.get_instance_custom_data(i)
   for c in 4:
    if actual[c]!=expected[i*4+c]:failures.append("rain data")
    rain_components+=1
 if rain.rng.calls!=int(reference.calls) or rain.rng.state!=int(reference.state) or absf(rain.thunder_timer-reference.thunder_timer)>1e-12:failures.append("rain initial RNG/timer")
 if game.source_scene.source.quality.name!=quality or game.render_quality.current!=quality:failures.append("source/render preset")
 game.game_flow.fade=0;game.game_ui.root.visible=false;game.view_camera.cull_mask=0
 for frame in 8:game._process(1.0/60);await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/cold-quality-"+quality+"-assets.png")
 var report={"quality":quality,"gpu_mip_hashes":checked.size(),"original_uv_bindings":uv_checks,"gpu_rain_components":rain_components,"rain_instances":rain.rain.multimesh.instance_count,"splash_instances":rain.splash.multimesh.instance_count,"render_quality":game.render_quality.current,"failures":failures,"scope":"Actual Main selected cold quality, original-font browser texture hashes and UV bindings, original literal rain data and RNG/timer. Eight rendered GPU frames; not complete pixel parity or performance."}
 FileAccess.open("res://evidence/cold-quality-"+quality+"-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
