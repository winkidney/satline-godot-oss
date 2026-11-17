extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
 var audio=load("res://scripts/original_audio.gd").new();root.add_child(audio)
 audio.set_process(false)
 audio.catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/original/manifest.json")).sounds
 audio._setup_buses();audio.set_master_volume(.8)
 audio.play_sound("rifle_shot",null,1.0,1.0,0,0)
 await create_timer(1.0).timeout
 audio.play_sound("step_metal",null,1.0,1.0,0,0)
 await create_timer(2.0).timeout
 print(JSON.stringify({"events":audio.event_log.map(func(item):return item.name),"output":AudioServer.get_output_device()}))
 audio.queue_free();await process_frame;await create_timer(.6).timeout;quit(0)
