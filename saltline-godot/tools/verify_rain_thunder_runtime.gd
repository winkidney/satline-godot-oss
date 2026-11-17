extends SceneTree
var game
var frame=0
var finishing=false
var ref:Dictionary
var events=[]
var failures=[]
var maximum=0.0
var frames_with_flash=0
var checks=0
func fail(message:String)->void:
 if failures.size()<20:failures.append({"frame":frame,"message":message})
func _initialize()->void:
 ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/rain-runtime-reference.json"));call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 game.flow_preview=false
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.rain_system.thunder.connect(func(value):events.append({"frame":frame,"intensity":value}))
 if game.animation_time!=0:fail("Main global clock used exported snapshot")
 if game.rain_system.rng!=game.source_bootstrap.streams.rain:fail("rain did not use shared child")
 if game.rain_system.rng.calls!=40641:fail("constructor consumed extra draw")
 if absf(game.rain_system.thunder_timer-ref.initial.thunder_timer)>1e-10:fail("initial timer mismatch")
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 var row=ref.frames[frame-1]
 game.rain_system.set_rain(row.target);game._process(.05)
 var rain=game.rain_system
 for pair in [[game.animation_time,rain.time],[rain.time,row.time],[rain.level,row.level],[rain.thunder_timer,row.timer]]:
  var error=absf(pair[0]-pair[1]);maximum=maxf(maximum,error);checks+=1
  if not is_finite(float(pair[0])) or error>1e-10:fail("rain scalar mismatch")
 checks+=3
 if rain.rng.calls!=int(row.rng_calls) or rain.rng.state!=int(row.rng_state):fail("rain RNG state/count mismatch")
 if events.size()!=row.thunder.size():fail("thunder event timing mismatch")
 for j in mini(events.size(),row.thunder.size()):
  if not is_finite(float(events[j].intensity)) or not is_finite(float(row.thunder[j])) or absf(events[j].intensity-row.thunder[j])>1e-10:fail("thunder intensity mismatch")
 if game.sky_weather.value>0:frames_with_flash+=1
 if events.size()>0 and events[-1].frame==frame:
  if game.sky_weather.value<=0:fail("thunder did not reach sky update")
  call_deferred("capture",frame)
 if frame>=ref.frames.size():finishing=true;call_deferred("finish")
 return false
func capture(at:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/rain-thunder-%04d.png"%at)
func finish()->void:
 var report={"frames":frame,"seconds":frame*.05,"checks":checks,"events":events,"flash_frames":frames_with_flash,"maximum_scalar_error":maximum,"rng_calls":game.rain_system.rng.calls,"failures":failures,"scope":"Actual Main ambient update at controlled dt.05, natural canonical rain thunder countdown/two events and shared RNG, sky value and rendered captures. Gameplay held at startup; no whole source frame/image or lightning direction random proof."}
 FileAccess.open("res://evidence/rain-thunder-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
