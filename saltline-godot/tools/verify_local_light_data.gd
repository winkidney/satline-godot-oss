extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 print("LOCAL_LIGHT_DATA waiting initial draw")
 RenderingServer.force_draw(false)
 print("LOCAL_LIGHT_DATA initial draw ready")
 game.flow_preview=false
 var data=game.source_local_light_data;var failures=[];var phases=[]
 var slot=game.light_pool.slots[1];game.light_pool.flash(Vector3(2,3,4),0xff8040,100,8,1)
 # Discover the chosen flash slot; persistent scan allocation may vary.
 var flash_index=-1
 for index in game.light_pool.slots.size():
  if game.light_pool.slots[index].peak==100:flash_index=index;slot=game.light_pool.slots[index]
 if flash_index<0:failures.append("flash source missing")
 var old_mask=slot.light.light_cull_mask;slot.light.light_cull_mask=(1<<17)|(1<<18)
 for entry in [["playing",.1],["paused",.02]]:
  game.game_flow.state=entry[0];var before=data.uploads;print("LOCAL_LIGHT_DATA process ",entry[0]);game._process(entry[1]);print("LOCAL_LIGHT_DATA draw ",entry[0]);await process_frame;RenderingServer.force_draw(false)
  var gpu=data.texture.get_image();var bytes_match=gpu.get_data()==data.image.get_data();var row=gpu.get_pixel(3,flash_index);var radiance=gpu.get_pixel(1,flash_index);var color=slot.light.light_color.srgb_to_linear()
  if not bytes_match:failures.append("RGBA32F GPU roundtrip "+entry[0])
  if data.uploads-before!=1 or absf(row.b-slot.source_intensity)>.00001 or row.r!=3 or row.g!=1:failures.append("render/source/mask state "+entry[0])
  if absf(radiance.r-color.r*slot.source_intensity)>.00001:failures.append("radiance used fallback /PI units")
  phases.append({"phase":entry[0],"source_intensity":row.b,"radiance_r":radiance.r,"source_mask":row.r,"gpu_bytes_exact":bytes_match,"uploads":data.uploads-before})
 slot.light.visible=false;game._process(0.0);await process_frame;RenderingServer.force_draw(false)
 if data.texture.get_image().get_pixel(3,flash_index).g!=0:failures.append("hidden light remains visible")
 slot.light.visible=true;slot.light.light_cull_mask=old_mask
 var static_rows=[]
 for row in range(6,10):
  var light=data.lights[row];var source=game.source_scene.records[data.identities[row]];var matrix=source.matrixWorld;var pixel=data.image.get_pixel(0,row)
  if Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(matrix[12],matrix[13],matrix[14]))>.00001 or pixel.a!=13 or data.image.get_pixel(3,row).b!=34:failures.append("static row "+str(row))
  static_rows.append(data.identities[row])
 game.camera.global_position=Vector3(0,1.68,-20);game._process(0.0);await process_frame;RenderingServer.force_draw(false)
 var key=data.texture.get_image().get_pixel(3,10)
 if absf(key.b-.495)>.000001 or key.r!=2:failures.append("key indoor source units/mask")
 var report={"phases":phases,"static_rows":static_rows,"key_indoor_intensity":key.b,"failures":failures,"scope":"Actual Main uploads once after pool decay, playing and paused. 4x11 RGBA32F full GPU byte roundtrip; dynamic flash source units, hidden flag, fallback high masks excluded, four original ordered static rows, indoor key. Atlas upload audit only; production BRDF parity has separate tests."}
 FileAccess.open("res://evidence/local-light-data-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
