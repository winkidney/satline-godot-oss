extends SceneTree
var game
var failures=[]
var checks=0
var frames=0
var minimum_health=100.0
var health_events=[]
func expect(condition:bool,label:String)->void:
 checks+=1
 if not condition:failures.append(label)
func _initialize()->void:call_deferred("run")
func step(controls:Dictionary)->void:
 frames+=1;game._game_tick(1.0/60,controls);game._process(1.0/60);minimum_health=minf(minimum_health,game.player.health)
func aim(actor)->Dictionary:
 var point:Vector3=actor.state.headPos
 var offset=point-game.player.eye
 var yaw=atan2(-offset.x,-offset.z);var pitch=atan2(offset.y,Vector2(offset.x,offset.z).length())
 var scale=lerpf(1.0,float(game.player.tuning.adsLook),game.weapon.ads)
 return {"dx":wrapf(game.player.yaw-yaw,-PI,PI)/scale,"dy":(game.player.pitch-pitch)/scale}
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 game.player.hit.connect(func(amount,_from):health_events.append({"frame":frames,"amount":amount,"health":game.player.health}))
 expect(not game.player.invulnerable,"normal vulnerable player")
 var first=game.enemy_manager.spawn("hound",Vector3(-24,0,6),{"yaw":-PI/2,"state":"alert","target":game.player.pos})
 expect(first!=null,"real actor spawned")
 if first==null:await finish({});return
 for i in 180:
  step({"move":Vector2.ZERO,"fire":false})
  if i%30==0:await process_frame
 var before=game.weapon.slots.rifle.ammo
 for i in 600:
  if not first.state.alive or not game.player.alive:break
  step({"move":Vector2.ZERO,"ads":true,"fire":true,"reload":game.weapon.slots.rifle.ammo==0,"look":aim(first)})
  if i%30==0:await process_frame
 expect(game.combat.stats.shots>0,"weapon fired through normal Main path")
 expect(game.combat.stats.hits>0,"actual weapon rays hit enemy")
 expect(game.combat.stats.kills>=1 and not first.state.alive,"real gun damage killed actor")
 expect(game.player.alive,"player survived first exchange")
 expect(not health_events.is_empty(),"enemy AI damaged normal player")
 var combat=game.combat.stats.duplicate(true);var killed=not first.state.alive
 if game.player.alive:
  game.enemy_manager.spawn("hound",Vector3(-24,0,6),{"yaw":-PI/2,"state":"alert","target":game.player.pos})
  for i in 1800:
   step({"move":Vector2.ZERO,"fire":false})
   if i%30==0:await process_frame
   if not game.player.alive:break
 expect(not game.player.alive and game.game_flow.state=="dead","enemy attacks trigger actual player death and flow")
 for i in 120:
  step({"move":Vector2.ZERO,"fire":false})
  if i%30==0:await process_frame
 expect(game.game_flow.menu=="dead","death menu after original delay")
 await process_frame;RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/main-combat-death.png")
 if game.game_ui.buttons.has("retry"):game.game_ui.buttons.retry.pressed.emit()
 else:failures.append("actual retry button absent")
 for i in 180:
  step({"move":Vector2.ZERO,"fire":false})
  if i%30==0:await process_frame
 expect(game.game_flow.state=="playing" and game.player.alive,"actual retry button restores gameplay")
 expect(game.player.health==100 and not game.player.invulnerable,"retry restores vulnerable full health")
 expect(game.mission.run.retries==1,"retry increments mission counter")
 await finish({"first_target_killed":killed,"combat":combat,"ammo_before":before,"minimum_health":minimum_health,"player_damage_events":health_events})
func finish(extra:Dictionary)->void:
 var report={"checks":checks,"failures":failures,"frames":frames,"scope":"Actual Main from source player spawn, controlled original hound spawns, normal weapon fire/rays/AI damage, vulnerable player death, delayed death menu and actual retry button. Automated aiming/stationary movement; not human combat or full mission balance acceptance."};report.merge(extra)
 FileAccess.open("res://evidence/main-combat-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
