extends SceneTree
func _initialize()->void:call_deferred("run")
func draw_game(game)->void:
 for warm in 3:game._process(0.0);await process_frame;RenderingServer.force_draw(false)
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{});game.flow_preview=false;RenderingServer.force_draw(false)
 var scene=game.source_scene;var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-detail-extraction.json"));var expected={};var failures=[];var bindings=[];var objects=[];var channels=0
 for record in reference.materials:
  expected[record.id]=record.kind;var material=scene.materials[record.id];var actual=material.get_shader_parameter("source_weapon_kind")
  if int(actual)!=int(record.kind):failures.append("detail kind mismatch "+record.name)
  bindings.append({"name":record.name,"kind":actual})
 if scene.weapon_detail_materials.size()!=6:failures.append("detail material count")
 for record in scene.source.nodes:
  var uses=false
  for id in record.get("materials",[]):
   if expected.has(id):uses=true
  if not uses:continue
  var node=scene.source_nodes[record.id];var geometry=scene.geometry_records[record.geometry];var actual=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0];var bytes=actual.to_byte_array() if actual is PackedFloat32Array else actual;var original=FileAccess.get_file_as_bytes("res://assets/export/"+geometry.attributes.aSurf.file)
  if bytes!=original:failures.append("aSurf GPU bytes mismatch "+record.id)
  var normals=FileAccess.get_file_as_bytes("res://assets/export/"+geometry.attributes.normal.file).to_float32_array();var packed=PackedFloat32Array();packed.resize(int(geometry.attributes.normal.count)*4)
  for vertex in int(geometry.attributes.normal.count):packed[vertex*4]=normals[vertex*3];packed[vertex*4+1]=normals[vertex*3+1];packed[vertex*4+2]=normals[vertex*3+2]
  var gpu_normal=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM2];var normal_bytes=gpu_normal.to_byte_array() if gpu_normal is PackedFloat32Array else gpu_normal;var normal_exact=normal_bytes==packed.to_byte_array()
  if not normal_exact:failures.append("unquantized normal GPU bytes mismatch "+record.id)
  channels+=int(geometry.attributes.aSurf.count)*4;objects.append({"id":record.id,"vertices":geometry.attributes.aSurf.count,"gpu_aSurf_exact":bytes==original,"gpu_normal_exact":normal_exact})
 var wetness=[];var value=scene.weapon_wetness
 for entry in [[Vector3(0,1.68,-20),"playing",.1,true],[Vector3(0,1.68,-20),"paused",.1,true],[Vector3(0,-100,-20),"paused",.02,true],[Vector3(-25,1.68,6),"playing",.1,false]]:
  game.camera.global_position=entry[0];game.game_flow.state=entry[1];value+=((.3 if entry[3] else 1.0)-value)*minf(1.0,minf(entry[2],.05)*(.25 if entry[3] else .6));game._process(entry[2]);await process_frame;RenderingServer.force_draw(false)
  var maximum=absf(scene.weapon_wetness-value)
  for binding in scene.weapon_wet_materials:maximum=maxf(maximum,absf(float(binding[0].get_shader_parameter(binding[1]))-value))
  wetness.append({"state":entry[1],"inside":entry[3],"expected":value,"actual":scene.weapon_wetness,"maximum_uniform_error":maximum})
  if maximum>.000001:failures.append("wetness timing/uniform "+entry[1])
 game.camera.global_position=Vector3(-11,1.68,-23);game.camera.look_at(Vector3(5,.5,-21),Vector3.UP);game.game_flow.state="playing";var images=[]
 for enabled in [false,true]:
  for record in reference.materials:scene.materials[record.id].set_shader_parameter("source_weapon_kind",int(record.kind) if enabled else -1)
  await draw_game(game);images.append(game.view_port.get_texture().get_image());root.get_texture().get_image().save_png("res://evidence/weapon-detail-on.png" if enabled else "res://evidence/weapon-detail-off.png")
 var changed=0;var maximum=0.0
 for y in range(0,images[0].get_height(),2):
  for x in range(0,images[0].get_width(),2):
   var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta)
   if delta>.003:changed+=1
 if changed<100:failures.append("actual weapon detail has no HDR contribution")
 var report={"materials":bindings,"objects":objects,"aSurf_channels":channels,"wetness":wetness,"changed_hdr_samples":changed,"maximum_rgb_difference":maximum,"failures":failures,"scope":"Actual six original PAC material bindings, all13 aSurf andunquantized normal mesh GPU byte audits, asymmetric inside .3/.25 andoutside1/.6 wetness with .05 dtcap andpaused updates applied to allsix+arms, actual weapon on/off HDR. Noise/core numerical profiles andbump derivative have separate originalGPU tests; full original material visual parity not claimed."};FileAccess.open("res://evidence/weapon-detail-runtime-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
