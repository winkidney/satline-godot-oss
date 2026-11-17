extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var reference={}
 for case in JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/transition-reversal-css.json")).opacity:
  if case.className=="hud":reference=case
 var failures=[];var samples=[];var maximum=0.0
 game.game_ui.announcements.show_message("Parent gate probe",10)
 var message_time=10.0
 for stage in reference.stages:
  game.game_flow.state="playing" if stage.on else "paused"
  var previous=0.0
  for sample in stage.samples:
   var dt=(sample.ms-previous)/1000.0;previous=sample.ms
   game.game_ui.update_frame(dt,game.animation_time)
   if stage.on:message_time-=dt
   if absf(game.game_ui.announcements.message_remaining-message_time)>1e-10:failures.append("message timer logical gate")
   var actual=game.game_ui.hud.modulate.a;var error=absf(actual-sample.alpha);maximum=maxf(maximum,error)
   if error>1e-5:failures.append({"on":stage.on,"ms":sample.ms,"actual":actual,"expected":sample.alpha})
   if game.game_ui.hud.visible!=(actual>0):failures.append("parent visible state")
   if game.game_ui.hud_on!=stage.on:failures.append("logical visibility target")
   samples.append({"on":stage.on,"ms":sample.ms,"alpha":actual,"expected":sample.alpha})
   await process_frame
 game.game_flow.state="playing";game.game_ui.panel_open=true;game.game_ui.update_frame(.01,game.animation_time)
 if game.game_ui.hud_on:failures.append("panel did not gate HUD")
 var report={"samples":samples,"maximum_error":maximum,"failures":failures,"scope":"Actual Main GameUI parent HUD opacity vs original Chrome six-interruption trace; logical HUD gate separately controls announcement timers and panel suppression. Controlled state assignment, not actual pause button input or whole frame parity."}
 FileAccess.open("res://evidence/hud-parent-reversal.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
