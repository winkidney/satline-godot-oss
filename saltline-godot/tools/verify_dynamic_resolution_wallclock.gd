extends SceneTree
var game
var frame=0
var finishing=false
var started_usec=0
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.game_ui.save_path="";started_usec=Time.get_ticks_usec()
 # Main retains its actual engine-driven process and physics callbacks.
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if (Time.get_ticks_usec()-started_usec>=8000000 and game.render_quality.measured_samples>=400) or frame>=10000:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 await process_frame;RenderingServer.force_draw(false)
 var quality=game.render_quality;var failures=[]
 if not quality.dynamic.state.enabled or quality.measured_samples<400 or quality.last_frame_ms<=0 or quality.dynamic.state.settle>0:failures.append("actual monotonic frame timing not consumed")
 var expected=quality.resolution(Vector2i(root.size),quality.PRESETS[quality.current],1,quality.dynamic.state.scale)
 if game.post_pipeline.world_port.size!=expected:failures.append("wallclock adaptation size")
 game.get_viewport().get_texture().get_image().save_png("res://evidence/dynamic-wallclock.png")
 var report={"observed_frames":frame,"elapsed_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"measured_samples":quality.measured_samples,"last_frame_ms":quality.last_frame_ms,"quality":quality.current,"state":quality.dynamic.state,"changes":quality.changes,"render_size":[expected.x,expected.y],"failures":failures,"scope":"Engine-driven Main update and physics with real Time.get_ticks_usec frame intervals, --dynres=1 override for script harness. Title scene, at least eight seconds of wall-clock observation, not performance target or gameplay benchmark."}
 FileAccess.open("res://evidence/dynamic-resolution-wallclock.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game.set_process(false);game.set_physics_process(false);game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
