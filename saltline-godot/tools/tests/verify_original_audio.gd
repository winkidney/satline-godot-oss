extends SceneTree

class MockWeapon extends RefCounted:
 var reload={"empty":false}
 var current="rifle"
class MockGame extends Node:
 var weapon=MockWeapon.new()

func _initialize()->void:call_deferred("_run")

func _run()->void:
 var audio=preload("res://scripts/original_audio.gd").new();root.add_child(audio);audio.game=MockGame.new()
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/original/manifest.json"))
 assert(manifest is Dictionary and manifest.sounds.size()==79)
 audio.catalog=manifest.sounds;audio._setup_buses()
 var effect_count=AudioServer.get_bus_effect_count(0);audio._setup_buses();assert(AudioServer.get_bus_effect_count(0)==effect_count)
 assert(AudioServer.get_bus_effect(0,0) is AudioEffectCompressor and AudioServer.get_bus_effect(0,1) is AudioEffectLimiter)
 var total=0;var loops=0
 for name in audio.catalog:
  var info:Dictionary=audio.catalog[name]
  for variant in info.variants.size():
   var stream=audio._stream(name,variant);var expected:Dictionary=info.variants[variant]
   assert(stream!=null and stream.mix_rate==int(expected.sample_rate))
   assert(stream.data.size()==int(expected.frames)*int(expected.channels)*2)
   if expected.loop:
    loops+=1;assert(stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and stream.loop_end==int(expected.frames))
   total+=1
 assert(total==136 and loops==14)
 audio.set_master_volume(.8);assert(not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0))-.8)<.0001)
 audio.set_master_volume(0);assert(AudioServer.is_bus_mute(0));audio.set_master_volume(.8);assert(not AudioServer.is_bus_mute(0))
 var settings=preload("res://scripts/source_settings.gd")
 assert(is_equal_approx(settings.decode("{}").volume,.8))
 assert(is_equal_approx(settings.decode('{"volume":2}').volume,1.0))
 assert(is_equal_approx(settings.decode('{"volume":-1}').volume,0.0))
 assert(is_equal_approx(settings.decode('{"volume":"bad"}').volume,.8))
 audio._weapon_fired("rifle",{},0);audio._weapon_phase("reload","rifle","boltback")
 audio._player_motion("step",{"surface":"metal","sprint":false})
 audio._shell_bounce(Vector3.ZERO,"metal",0)
 var names=audio.event_log.map(func(item):return item.name)
 assert("rifle_shot" in names and "rifle_tail_out" in names and "reload_boltback" in names and "step_metal" in names and "shell_bounce_metal" in names)
 var bolt=audio.event_log.filter(func(item):return item.name=="reload_boltback")[0]
 assert(bolt.variant==1 and is_equal_approx(bolt.gain,.6))
 var relay={"id":"test","o":{"pos":Vector3.ZERO}}
 audio._relay_changed(relay,"live");audio._relay_changed(relay,"live");assert(audio.relay_loops.size()==1)
 audio._relay_changed(relay,"cut");assert(audio.relay_loops.is_empty())
 audio._start_score();assert(audio.score.stream_count==7 and audio.score_player.playing)
 print(JSON.stringify({"definitions":audio.catalog.size(),"buffers":total,"loops":loops,"events":names,"volume_default":.8}))
 audio.game.free();audio.queue_free();await process_frame;await create_timer(.6).timeout;quit(0)
