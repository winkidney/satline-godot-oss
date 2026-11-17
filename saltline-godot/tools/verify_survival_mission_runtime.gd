extends SceneTree
var failures=[]
var legs=[]
var frames=0
var distance=0.0
var damage_events=[]
var minimum_health=100.0
var protected_live_frames=0
var controlled_focus_resumes=0
func _initialize()->void:
 seed(4207)
 call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_ui._select("difficulty","standard");game.game_flow.start("mission",false,false,true)
 game.player.hit.connect(func(amount,_from):damage_events.append({"frame":frames,"amount":amount,"health":game.player.health}))
 var start=game.player.pos
 for leg in 4:
  var target:Vector3=game.mission.relays[leg].o.pos if leg<3 else game.mission.extraction.pos
  var path=game.navigation.find_path(game.player.pos,target)
  if path==null:failures.append("no route for leg %d"%leg);break
  var waypoint=0
  var before=frames
  var done=false
  while frames-before<3600 and game.player.alive:
   frames+=1
   if game.game_flow.state=="paused":game.game_flow.resume();controlled_focus_resumes+=1
   if game.player.invulnerable and game.game_flow.state in ["intro","playing"]:protected_live_frames+=1
   var offset=target-game.player.pos;offset.y=0
   var near=offset.length()<float(game.mission.flow.interactRange)-.15 if leg<3 else offset.length()<2.0
   var goal:Vector3=target if near or waypoint>=path.size() else path[waypoint]
   var delta=goal-game.player.pos;delta.y=0
   if not near and delta.length()<.25 and waypoint<path.size()-1:waypoint+=1;continue
   var attack={};var nearest=30.0
   if not near:
    for actor in game.enemy_manager.active:
     if not actor.state.alive:continue
     var point:Vector3=actor.state.headPos if actor.state.type=="hound" else actor.state.pos
     var range_to=point.distance_to(game.player.eye)
     if range_to<nearest and game.player.physics.line_of_sight(game.player.eye,point):nearest=range_to;attack={"point":point}
   var aiming=attack.point-game.player.eye if not attack.is_empty() else offset if near else delta
   var desired=atan2(-aiming.x,-aiming.z)
   var pitch=atan2(aiming.y,Vector2(aiming.x,aiming.z).length()) if not attack.is_empty() else 0.0
   var scale=lerpf(1,float(game.player.tuning.adsLook),game.weapon.ads)
   var turn=wrapf(game.player.yaw-desired,-PI,PI)/scale
   var direction=delta.normalized()
   var sy=sin(desired);var cy=cos(desired)
   var movement=Vector2(direction.x*cy-direction.z*sy,-direction.x*sy-direction.z*cy)
   if near:movement=Vector2.ZERO
   game.source_keyboard_input.key(KEY_E,near and leg<3)
   var previous=game.player.pos
   var slot=game.weapon.slots[game.weapon.current]
   var firing=not attack.is_empty() and (game.weapon.current=="rifle" or frames%8==0)
   game._game_tick(1.0/30,{"move":movement,"ads":firing,"fire":firing,"reload":slot.ammo==0 and slot.reserve>0,"weapon2":game.weapon.current=="rifle" and slot.ammo==0 and slot.reserve==0,"look":{"dx":turn,"dy":(game.player.pitch-pitch)/scale}})
   minimum_health=minf(minimum_health,game.player.health)
   distance+=game.player.pos.distance_to(previous)
   if frames%100==0:await process_frame
   if (leg<3 and game.mission.relays[leg].cut) or (leg==3 and game.game_flow.state=="complete"):done=true;break
  legs.append({"leg":leg,"steps":frames-before,"done":done,"position":[game.player.pos.x,game.player.pos.y,game.player.pos.z],"waypoints":path.size(),"reached_waypoint":waypoint})
  if not done:failures.append("movement stalled leg %d"%leg);break
 game.source_keyboard_input.key(KEY_E,false)
 if game.game_flow.state!="complete":failures.append("mission not completed by walking")
 if protected_live_frames>0:failures.append("player protected during gameplay")
 if game.game_flow.state=="complete":
  for i in 120:
   game._game_tick(1.0/30,{"move":Vector2.ZERO,"fire":false});game._process(1.0/30)
   if i%30==0:await process_frame
  if game.game_flow.menu!="complete":failures.append("delayed completion card absent")
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/survival-mission-complete.png")
 if game.navigation.rng!=game.fx_random:failures.append("navigation did not share source Math.random namespace")
 var report={"controlled_focus_resumes":controlled_focus_resumes,"test_only_global_seed":4207,"shared_navigation_fx_random":game.navigation.rng==game.fx_random,"failures":failures,"frames":frames,"distance":distance,"start":[start.x,start.y,start.z],"legs":legs,"cut":game.mission.run.cut,"state":game.game_flow.state,"health":game.player.health,"minimum_health":minimum_health,"protected_live_frames":protected_live_frames,"completion_menu":game.game_flow.menu,"rifle_ammo":game.weapon.slots.rifle.ammo,"rifle_reserve":game.weapon.slots.rifle.reserve,"debrief":game.mission.debrief,"difficulty":game.mission.difficulty,"combat":game.combat.stats,"damage_events":damage_events,"scope":"Actual Main from original spawn with normal player movement/capsule collision and keyboard E holds. Original Standard difficulty and patrols, automated navigation/aim/fire with normal health/ammo/AI, no invulnerability, teleports, direct damage or direct relay cuts. Test-only global seed4207 and controlled resumes after desktop focus loss; production random stream and pause behavior unchanged. Not human play/balance acceptance."}
 FileAccess.open("res://evidence/survival-mission-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
