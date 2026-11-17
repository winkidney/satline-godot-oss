extends SceneTree
var failures=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message)
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 check(game.source_scene.source.quality.name=="low","source quality")
 var texture_checks=0
 for record in game.source_scene.source.textures:
  if not str(record.get("godot_file","")).contains("/materials-full-low/") and not str(record.get("godot_file","")).contains("/ground/low/"):continue
  var texture=game.source_scene._texture({"$texture":record.id},true)
  var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(texture.get_image().get_data())
  check(hash.finish().hex_encode()==record.source_sha256,"GPU mip hash "+record.id);texture_checks+=1
 check(texture_checks==76,"replacement count")
 var original=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/original-low-material-bindings.json"))
 var uv_checks=0
 for binding in original.bindings:
  if not binding.has("uv"):continue
  var record={}
  for material in game.source_scene.source.materials:
   if material.id==binding.material:record=material;break
  var uv=record.patch.uniforms.uSlUv.value
  check(uv==binding.uv,"original UV metadata "+binding.material)
  var material=game.source_scene.materials[binding.material]
  check(material.get_shader_parameter("tri_scale")==binding.uv[2],"native sampling parameter "+binding.material)
  var scale=material.get_shader_parameter("source_uv_scale")
  check(scale==Vector2(binding.uv[0],binding.uv[1]),"native UV scale "+binding.material)
  uv_checks+=1
 var rain=game.rain_system
 check(rain.rain.multimesh.instance_count==4760,"rain count")
 check(rain.splash.multimesh.instance_count==450,"splash count")
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/rain-initialization.json"))
 var reference={}
 for case in fixture.cases:
  if case.quality=="low":reference=case
 check(rain.rng.calls==int(reference.calls) and rain.rng.state==int(reference.state),"rain RNG")
 check(absf(rain.thunder_timer-reference.thunder_timer)<1e-12,"initial thunder timer")
 var rain_components=0
 for entry in [[rain.rain,"rain"],[rain.splash,"splash"]]:
  var expected=FileAccess.get_file_as_bytes("res://assets/export/"+reference.files[entry[1]]).to_float32_array()
  for i in entry[0].multimesh.instance_count:
   var value=entry[0].multimesh.get_instance_custom_data(i)
   for c in 4:check(value[c]==expected[i*4+c],"GPU rain seed %s/%d/%d"%[entry[1],i,c]);rain_components+=1
 check(game.ground_queries.resolution==512,"ground query resolution")
 check(game.ground_queries.mask_path=="res://assets/ground/low/uMask.cpu-rgba","ground query asset")
 game.game_flow.fade=0;game.game_ui.root.visible=false;game.view_camera.cull_mask=0
 for frame in 8:game._process(1.0/60);await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/cold-quality-low-assets.png")
 var report={"failures":failures,"original_uv_bindings":uv_checks,"gpu_mip_hashes":texture_checks,"gpu_rain_components":rain_components,"rain_instances":rain.rain.multimesh.instance_count,"splash_instances":rain.splash.multimesh.instance_count,"asset_bindings":game.source_scene.report.cold_quality_assets,"query_resolution":game.ground_queries.resolution,"scope":"Actual Main low cold assets: complete replaced texture GPU mip hashes, original literal low rain GPU attributes and initial RNG/timer, CPU mask binding and rendered frame. Not whole-original pixel parity, input playthrough or performance."}
 FileAccess.open("res://evidence/cold-quality-low-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
