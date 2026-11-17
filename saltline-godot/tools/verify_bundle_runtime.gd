extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var failures=[]
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 game.game_flow.start();game._process(.05)
 var backdrop=game.source_scene.backdrop_time;var rain=game.rain_system.time
 if backdrop<=0 or rain<=0:failures.append("active clocks did not advance")
 game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 if game.game_flow.state!="paused":failures.append("focus-loss pause")
 for frame in 4:game._process(.05);await process_frame
 if game.source_scene.backdrop_time!=backdrop or game.rain_system.time!=rain:failures.append("paused visual clocks advanced")
 game.game_ui.buttons.resume.pressed.emit();game._process(.05)
 if game.source_scene.backdrop_time<=backdrop or game.rain_system.time<=rain:failures.append("resume clocks frozen")
 for frame in 4:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/bundle-integration.png")
 var quality=game.source_scene.source.quality.name
 if quality=="low" and (game.rain_system.rain.multimesh.instance_count!=4760 or game.ground_queries.resolution!=512):failures.append("cold-low assets missing")
 var report={"failures":failures,"project_path":ProjectSettings.globalize_path("res://"),"executable":OS.get_executable_path(),"quality":quality,"backdrop_bindings":game.source_scene.backdrop_motion.keys(),"rain_instances":game.rain_system.rain.multimesh.instance_count,"splash_instances":game.rain_system.splash.multimesh.instance_count,"query_resolution":game.ground_queries.resolution,"scope":"Packaged actual Main low startup, injected focus-loss pause, backdrop/rain freeze and actual Resume button, GPU capture. Not OS focus delivery, whole pixel parity, full mission or performance."}
 FileAccess.open("res://evidence/bundle-integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
