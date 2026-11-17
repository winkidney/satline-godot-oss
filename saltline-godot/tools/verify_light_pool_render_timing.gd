extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 await RenderingServer.frame_post_draw
 var pool=game.light_pool;pool.flash(Vector3.ZERO,0xffffff,100,10,1);var slot:Dictionary
 for candidate in pool.slots:
  if candidate.busy and not candidate.persistent and candidate.peak==100:slot=candidate
 var failures=[];var phases=[];var initial_updates=pool.updates
 for tick in 4:game._game_tick(1.0/60,{})
 phases.append({"phase":"four_physics_ticks","updates":pool.updates-initial_updates,"ttl":slot.ttl,"source_intensity":slot.source_intensity})
 if pool.updates!=initial_updates or absf(slot.ttl-1.0)>.000001:failures.append("physics effects also decayed light pool")
 for entry in [["playing",.1,.95],["paused",.1,.90],["paused",.02,.88]]:
  game.game_flow.state=entry[0];var before=pool.updates;game._process(entry[1]);var expected=float(entry[2]);phases.append({"phase":entry[0],"render_dt":entry[1],"updates":pool.updates-before,"ttl":slot.ttl,"source_intensity":slot.source_intensity,"native_energy":slot.light.light_energy})
  if pool.updates-before!=1 or absf(slot.ttl-expected)>.000001 or absf(slot.source_intensity-expected*100)>.00001 or absf(slot.light.light_energy-slot.source_intensity/PI)>.00001:failures.append("render timing or units mismatch "+entry[0])
 var persistent=pool.acquire();pool.set_energy(persistent,42);game._process(.1)
 if persistent.source_intensity!=42 or absf(persistent.light.light_energy-42/PI)>.00001:failures.append("persistent source energy decayed")
 await RenderingServer.frame_post_draw
 var report={"phases":phases,"persistent_source_intensity":persistent.source_intensity,"failures":failures,"scope":"Actual Main game_tick vs render_process paths:4 physics ticks do not decay pool;each playing/paused render decays exactlyonce with original .05dt cap;source values andnative /PI remain separate. Persistent energy retained. Not customlocal BRDF or full flashvisual parity."};FileAccess.open("res://evidence/light-pool-render-timing-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
