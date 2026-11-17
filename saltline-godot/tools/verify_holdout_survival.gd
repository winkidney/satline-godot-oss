extends SceneTree

var failures=[]
var frames=0
var resumes=0
var waves=[]
var damage=[]

func _initialize()->void:
 seed(4207);call_deferred("run")

func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 game.game_ui._select("difficulty","standard");game.game_flow.start("holdout",false,false,true)
 game.mission.wave_started.connect(func(wave,count):waves.append({"wave":wave,"count":count}))
 game.player.hit.connect(func(amount,_from):damage.append({"frame":frames,"amount":amount,"health":game.player.health}))
 var start=game.player.pos;var distance=0.0;var protected_frames=0
 var path=[];var waypoint=0;var target_id=-1
 while frames<18000 and game.player.alive and game.mission.run.wavesCleared<2:
  frames+=1
  if game.game_flow.state=="paused":game.game_flow.resume();resumes+=1
  if game.player.invulnerable:protected_frames+=1
  var target=null;var nearest=INF;var visible=false
  for actor in game.enemy_manager.active:
   if not actor.state.alive:continue
   var point:Vector3=actor.state.headPos if actor.state.type=="hound" else actor.state.pos
   var seen=game.player.physics.line_of_sight(game.player.eye,point)
   var score=game.player.eye.distance_to(point)+(0 if seen else 1000)
   if score<nearest:target=actor;nearest=score;visible=seen
  var movement=Vector2.ZERO;var look={"dx":0.0,"dy":0.0};var firing=false
  if target!=null:
   var point:Vector3=target.state.headPos if target.state.type=="hound" else target.state.pos
   if target_id!=int(target.state.id) or frames%30==0:
    var route=game.navigation.find_path(game.player.pos,target.state.pos)
    path=[] if route==null else route;waypoint=0;target_id=int(target.state.id)
   while waypoint<path.size()-1 and game.player.pos.distance_to(path[waypoint])<.4:waypoint+=1
   var delta:Vector3=(path[waypoint] if waypoint<path.size() else target.state.pos)-game.player.pos;delta.y=0
   var aim:Vector3=point-game.player.eye if visible else delta
   var yaw=atan2(-aim.x,-aim.z);var pitch=atan2(aim.y,Vector2(aim.x,aim.z).length()) if visible else 0.0
   var scale=lerpf(1,float(game.player.tuning.adsLook),game.weapon.ads)
   look={"dx":wrapf(game.player.yaw-yaw,-PI,PI)/scale,"dy":(game.player.pitch-pitch)/scale}
   if not visible or game.player.eye.distance_to(point)>24:
    var direction=delta.normalized();movement=Vector2(direction.x*cos(yaw)-direction.z*sin(yaw),-direction.x*sin(yaw)-direction.z*cos(yaw))
   firing=visible and (game.weapon.current=="rifle" or frames%8==0)
  var slot=game.weapon.slots[game.weapon.current];var before=game.player.pos
  game._game_tick(1.0/30,{"move":movement,"look":look,"ads":firing,"fire":firing,"reload":slot.ammo==0 and slot.reserve>0,"weapon2":game.weapon.current=="rifle" and slot.ammo==0 and slot.reserve==0})
  distance+=game.player.pos.distance_to(before)
  if frames%100==0:await process_frame
 if game.mission.run.wavesCleared<2:failures.append("did not clear two waves")
 if protected_frames>0:failures.append("protected player")
 if game.combat.stats.shots<=0 or game.combat.stats.kills<16:failures.append("normal shot/kill chain incomplete")
 for i in 60:
  game._process(1.0/30)
  if i%15==0:await process_frame
 await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://evidence/holdout-survival.png")
 var report={"failures":failures,"frames":frames,"waves":waves,"waves_cleared":game.mission.run.wavesCleared,"health":game.player.health,"state":game.game_flow.state,"protected_frames":protected_frames,"combat":game.combat.stats,"damage":damage,"distance":distance,"start":[start.x,start.y,start.z],"controlled_focus_resumes":resumes,"test_only_global_seed":4207,"scope":"Actual Main Standard Holdout, normal health/ammo/AI, automated navigation and aim/fire. No direct actor damage, teleport, invulnerability or wave advancement. Controlled simulation ticks and final GPU capture, not human balance or real-time performance acceptance."}
 FileAccess.open("res://evidence/holdout-survival.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
