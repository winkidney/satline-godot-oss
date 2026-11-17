extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var saved="low";var expected="low";var tag="saved-low"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--saved-quality="):saved=arg.trim_prefix("--saved-quality=")
  if arg.begins_with("--expected-quality="):expected=arg.trim_prefix("--expected-quality=")
  if arg.begins_with("--case="):tag=arg.trim_prefix("--case=")
 if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/saltline-quality-precedence-"):quit(2);return
 FileAccess.open("user://saltline-settings.json",FileAccess.WRITE).store_string(JSON.stringify({"quality":saved}))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var failures=[];var initial=game.render_quality.current
 if game.game_ui.settings.quality!=saved:failures.append("saved setting lost")
 if initial!=expected or game.game_ui.effective_quality!=expected:failures.append("startup precedence")
 var source_quality=game.source_scene.source.quality.name;var rain_instances=game.rain_system.rain.multimesh.instance_count
 game.game_ui.setting_changed.emit("quality","medium")
 if game.render_quality.current!="medium":failures.append("explicit live menu change ignored")
 if game.source_scene.source.quality.name!=source_quality or game.rain_system.rain.multimesh.instance_count!=rain_instances:failures.append("menu rebaked source assets")
 for frame in 4:game._process(0.0);await process_frame
 var report={"case":tag,"saved":saved,"initial_render_quality":initial,"expected":expected,"source_quality":source_quality,"rain_instances":rain_instances,"menu_render_quality":game.render_quality.current,"failures":failures,"scope":"Actual Main isolated saved settings, explicit cold-quality priority and runtime quality signal. Menu signal tests apply behavior, not pointer click delivery."}
 FileAccess.open("res://evidence/quality-precedence-"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
