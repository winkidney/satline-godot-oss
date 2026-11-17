extends SceneTree

func _initialize()->void:call_deferred("_run")

func require(value:bool,message:String)->bool:
 if not value:push_error(message);quit(1);return false
 return true

func _run()->void:
 var game=load("res://scenes/main.tscn").instantiate();var ready=[false]
 game.initialization_complete.connect(func():ready[0]=true);root.add_child(game)
 var deadline=Time.get_ticks_msec()+30000
 while not ready[0] and Time.get_ticks_msec()<deadline:await process_frame
 if not require(ready[0] and game.original_audio!=null,"Game audio did not initialize"):return
 var audio=game.original_audio
 if not require(audio.catalog.size()==79 and audio.score_player.playing,"Audio catalog or score did not start"):return
 if not require(audio.relay_loops.size()==game.mission.relays.size(),"Relay ambience did not initialize"):return
 game.weapon.phase_event.emit("dry","rifle","")
 game.player.motion_event.emit("step",{"surface":"metal","sprint":false,"pos":Vector3.ZERO})
 game.shells.bounced.emit(Vector3.ZERO,"metal",0)
 game.game_ui._select("volume",.35)
 if not require(absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.35)<.0001,"Volume setting did not reach master bus"):return
 var names=audio.event_log.map(func(item):return item.name)
 if not require("rifle_dry" in names and "step_metal" in names and "shell_bounce_metal" in names,"Audio event routing is incomplete"):return
 print(JSON.stringify({"audio_initialized":true,"events":names,"saved_volume":game.game_ui.settings.volume,"score_layers":audio.score.stream_count}))
 game.queue_free();await process_frame;await create_timer(.2).timeout;quit(0)
