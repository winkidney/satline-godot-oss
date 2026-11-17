extends SceneTree
var game
var frame=0
var failures=[]
var starting_pos:Vector3
var starting_yaw=0.0
var released_shots=0
var reload_ammo=0
var reload_reserve=0.0
var reload_checks={}
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false;game.game_ui.save_path="";game.player.invulnerable=true
 starting_pos=game.player.pos;starting_yaw=game.player.yaw
func finger(id:int,point:Vector2,pressed:bool,canceled:bool=false)->void:
 var e=InputEventScreenTouch.new();e.index=id;e.position=point;e.pressed=pressed;e.canceled=canceled;Input.parse_input_event(e)
func drag(id:int,point:Vector2)->void:
 var e=InputEventScreenDrag.new();e.index=id;e.position=point;Input.parse_input_event(e)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==5:finger(1,Vector2(100,500),true);finger(2,Vector2(800,300),true)
 if frame==8:drag(1,Vector2(100,442));drag(2,Vector2(820,290))
 if frame==45:
  if game.weapon.shot_count!=0:failures.append("emulated mouse fired before FIRE touch")
  if game.player.pos.distance_to(starting_pos)<.2:failures.append("stick movement")
  if absf(game.player.yaw-starting_yaw)<.05:failures.append("right drag look")
  if not game.source_touch_input.sprint():failures.append("forward auto sprint")
 if frame==50:finger(1,Vector2(100,442),false);finger(2,Vector2(820,290),false)
 if frame==60:finger(3,Vector2(1130,656),true)
 if frame==61:finger(3,Vector2(1130,656),false)
 if frame==65:
  finger(4,Vector2(1217,615),true);game.player.health=70;game.game_ui.comms.enqueue("Touch layout: keep the thumbs' corners clear.",5);game.game_ui.feedback.enemy_killed("hound",frame)
 if frame==75:drag(4,Vector2(1227,605))
 if frame==110:
  if game.game_ui.navigation_hud.compass_width!=300 or not game.game_ui.radio.touch_layout:failures.append("touch HUD layout flags")
  if game.weapon.shot_count<=0:failures.append("fire button")
  if game.player.ads<.5:failures.append("ads toggle")
  RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/touch-runtime.png")
 if frame==120:finger(4,Vector2(1227,605),false)
 if frame==130:finger(3,Vector2(1130,656),true)
 if frame==125:released_shots=game.weapon.shot_count
 if frame==145 and game.weapon.shot_count!=released_shots:failures.append("fire continued after release")
 if frame==131:finger(3,Vector2(1130,656),false)
 if frame==150:finger(5,Vector2(1161,497),true)
 if frame==151:finger(5,Vector2(1161,497),false)
 if frame==190 and game.weapon.current!="pistol":failures.append("swap button")
 if frame==200:finger(6,Vector2(1247,33),true)
 if frame==201:finger(6,Vector2(1247,33),false)
 if frame==210:
  if game.game_flow.state!="paused":failures.append("pause button")
  if not game.source_touch_input.held.is_empty() or game.source_touch_input.ads:failures.append("pause clear")
  if game.touch_overlay.visible:failures.append("pause overlay visibility")
 if frame==220:game.game_flow.resume()
 if frame==230:finger(7,Vector2(1230,526),true)
 if frame==231:finger(7,Vector2(1230,526),false)
 if frame==240 and game.player.pos.y<.1:failures.append("jump button")
 if frame==250:
  game.player.reset({"pos":game.mission.relays[0].o.pos+Vector3(0,0,1.3),"yaw":0},game.camera);game.player.invulnerable=true
 if frame==265:
  if not game.touch_overlay.prompt or game.game_ui.status_hud.interaction.key!="USE":failures.append("touch USE prompt")
 if frame==270:finger(8,Vector2(1060,590),true)
 if frame==330:
  RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/touch-interaction.png")
 if frame==440:finger(8,Vector2(1060,590),false)
 if frame==460 and game.mission.run.cut!=1:failures.append("USE relay cut")
 if frame==465:finger(9,Vector2(1161,497),true)
 if frame==466:finger(9,Vector2(1161,497),false)
 if frame==515:
  reload_ammo=game.weapon.slots.rifle.ammo;reload_reserve=game.weapon.slots.rifle.reserve
  if game.weapon.current!="rifle" or reload_ammo>=game.weapon.slots.rifle.mag_size:failures.append("reload precondition")
 if frame==520:finger(10,Vector2(1145,567),true)
 if frame==521:finger(10,Vector2(1145,567),false)
 if frame==530:
  reload_checks.started=not game.weapon.reload.is_empty()
  if not reload_checks.started:failures.append("RLD starts reload")
 if frame==720:
  reload_checks.completed=game.weapon.reload.is_empty() and game.weapon.slots.rifle.ammo==game.weapon.slots.rifle.mag_size
  reload_checks.reserve=game.weapon.slots.rifle.reserve==reload_reserve-(game.weapon.slots.rifle.mag_size-reload_ammo)
  if not reload_checks.completed or not reload_checks.reserve:failures.append("RLD completion / reserve accounting")
 if frame==730:finger(11,Vector2(100,500),true);finger(12,Vector2(800,300),true);finger(13,Vector2(1217,615),true)
 if frame==733:drag(11,Vector2(100,442));drag(12,Vector2(810,300))
 if frame==738:
  finger(11,Vector2(100,442),false,true);finger(12,Vector2(810,300),false,true);finger(13,Vector2(1217,615),false,true)
 if frame==745:
  if game.source_touch_input.stick_id!=-1 or game.source_touch_input.look_id!=-1 or game.source_touch_input.fire_id!=-1 or game.source_touch_input.down("fire") or not game.touch_buttons.is_empty():failures.append("multi finger cancel ownership")
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame==760:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 var report={"frames":frame,"shots":game.weapon.shot_count,"cut":game.mission.run.cut,"reload_checks":reload_checks,"weapon":game.weapon.current,"state":game.game_flow.state,"failures":failures,"scope":"Actual Main with injected native ScreenTouch/ScreenDrag: stick/look, sprint, ADS, fire drag/release, swap, pause/clear/resume, jump, USE relay, RLD start/complete/reserve and three-finger cancellation. No physical touchscreen, safe-area or full source HUD pixel parity."}
 FileAccess.open("res://evidence/touch-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
