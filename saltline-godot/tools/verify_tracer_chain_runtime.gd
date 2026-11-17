extends SceneTree
var game
var frame=0
var finishing=false
var failures=[]
var checks=0
var shot_events=[]
var smoke_events=[]
var before_tracer=0
var before_shell=0
var before_root=Transform3D.IDENTITY
var active_impact=false
var shot_frame=0
var focus_resumes=0
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.player.reset({"pos":Vector3(-20,0,-.5),"yaw":0},game.camera);game.player.invulnerable=true
 game.combat.impact.connect(observe_impact)
 game.weapon.fired.connect(observe_fire)
 game.weapon.smoke_requested.connect(observe_smoke)
func observe_impact(hit:Dictionary)->void:
 if hit.get("from")!="player":return
 checks+=2
 if game.tracers.emitted!=before_tracer or game.shells.emitted!=before_shell:failures.append("impact occurred after tracer/shell")
 active_impact=true;shot_frame=frame
func observe_fire(_gun:String,_definition:Dictionary,_spread:float)->void:
 checks+=3
 if not active_impact or shot_frame!=frame:failures.append("weapon signal did not pass synchronous impact callback")
 if game.tracers.emitted!=before_tracer+1 or game.shells.emitted!=before_shell+1:failures.append("tracer/shell not emitted after impact")
 var trail=absf(game.impact_effects.tracer_trail_time-game.impact_effects.clock)<1e-12
 shot_events.append({"frame":frame,"tracer":game.tracers.emitted,"shell":game.shells.emitted,"trail":trail})
func observe_smoke(options:Dictionary)->void:
 var root_node=game.source_scene.source_nodes[game.weapon.rigs[game.weapon.current].root["$node"]];checks+=2
 if root_node.transform!=before_root:failures.append("smoke used already-updated gun root")
 if options.count!=1 or options.life!=1.3 or options.rise!=.5 or options.alpha!=.22:failures.append("weapon smoke options")
 smoke_events.append({"frame":frame,"heat":game.weapon.heat,"options":options.duplicate(true),"lit":game.impact_effects.lit_pool.emitted})
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 # Scripted input is independent of desktop focus; preserve production focus-pause behavior.
 if game.game_flow.state=="paused":game.game_flow.resume();focus_resumes+=1
 frame+=1;active_impact=false;before_tracer=game.tracers.emitted;before_shell=game.shells.emitted
 before_root=game.source_scene.source_nodes[game.weapon.rigs[game.weapon.current].root["$node"]].transform
 var smoke_before=smoke_events.size()
 var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"jump":false,"interact":false,"ads":false,"fire":frame>=30 and frame<90,"reload":false,"weapon2":false,"weapon1":false,"swap":false}
 game._game_tick(1.0/60,input);game._process(1.0/60)
 if smoke_events.size()>smoke_before:
  checks+=1
  if absf(game.weapon.heat-maxf(0,smoke_events[-1].heat-(1.0/60)*.2))>1e-10:failures.append("smoke not emitted before heat decay")
 if frame in [75,115]:call_deferred("capture",frame)
 if frame>=480:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/tracer-chain-%03d.png"%requested)
func finish()->void:
 checks+=4
 if shot_events.is_empty() or not shot_events.any(func(e):return e.trail):failures.append("actual long-tracer smoke trail not reached")
 if smoke_events.is_empty():failures.append("actual heated weapon smoke not reached")
 if not game.impact_effects.pool.particles.is_empty() or not game.impact_effects.lit_pool.particles.is_empty() or not game.tracers.shots.is_empty():failures.append("particle/tracer lifecycle not cleared")
 var report={"controlled_focus_resumes":focus_resumes,"frames":frame,"checks":checks,"shots":shot_events,"smoke":smoke_events,"remaining_add":game.impact_effects.pool.particles.size(),"remaining_lit":game.impact_effects.lit_pool.particles.size(),"remaining_tracers":game.tracers.shots.size(),"failures":failures,"scope":"Actual Main continuous rifle burst: synchronous impact before tracer/shell, trail reached, heated smoke before root update and heat decay, and particle/tracer clear. Controlled player pose/input; no original whole-frame tape or paired pixels."}
 FileAccess.open("res://evidence/tracer-chain-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
