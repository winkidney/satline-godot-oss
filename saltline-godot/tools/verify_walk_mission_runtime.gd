extends SceneTree
var failures=[]
var legs=[]
var frames=0
var distance=0.0
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_flow.start("mission",false,false,true);game.player.invulnerable=true
 var start=game.player.pos
 for leg in 4:
  var target:Vector3=game.mission.relays[leg].o.pos if leg<3 else game.mission.extraction.pos
  var path=game.navigation.find_path(game.player.pos,target)
  if path==null:failures.append("no route for leg %d"%leg);break
  var waypoint=0
  var before=frames
  var done=false
  while frames-before<2400:
   frames+=1
   var offset=target-game.player.pos;offset.y=0
   var near=offset.length()<float(game.mission.flow.interactRange)-.15 if leg<3 else offset.length()<2.0
   var goal:Vector3=target if near or waypoint>=path.size() else path[waypoint]
   var delta=goal-game.player.pos;delta.y=0
   if not near and delta.length()<.25 and waypoint<path.size()-1:waypoint+=1;continue
   var aim=offset if near else delta
   var desired=atan2(-aim.x,-aim.z)
   var turn=wrapf(game.player.yaw-desired,-PI,PI)
   var direction=delta.normalized()
   var sy=sin(desired);var cy=cos(desired)
   var movement=Vector2(direction.x*cy-direction.z*sy,-direction.x*sy-direction.z*cy)
   if near:movement=Vector2.ZERO
   game.source_keyboard_input.key(KEY_E,near and leg<3)
   var previous=game.player.pos
   game._game_tick(1.0/30,{"move":movement,"fire":false,"look":{"dx":turn,"dy":0.0}})
   distance+=game.player.pos.distance_to(previous)
   if frames%100==0:await process_frame
   if (leg<3 and game.mission.relays[leg].cut) or (leg==3 and game.game_flow.state=="complete"):done=true;break
  legs.append({"leg":leg,"steps":frames-before,"done":done,"position":[game.player.pos.x,game.player.pos.y,game.player.pos.z],"waypoints":path.size(),"reached_waypoint":waypoint})
  if not done:failures.append("movement stalled leg %d"%leg);break
 game.source_keyboard_input.key(KEY_E,false)
 if game.game_flow.state!="complete":failures.append("mission not completed by walking")
 var report={"failures":failures,"frames":frames,"distance":distance,"start":[start.x,start.y,start.z],"legs":legs,"cut":game.mission.run.cut,"state":game.game_flow.state,"scope":"Actual Main from original spawn with normal player movement/capsule collision and keyboard E holds. Navigation drives movement/look; invulnerable player, no teleports or direct relay cuts. Not human combat acceptance."}
 FileAccess.open("res://evidence/walk-mission-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
