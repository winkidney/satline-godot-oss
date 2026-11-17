extends SceneTree
var game
var frame=0
var failures=[]
var events=[]
var debrief={}
var checks=0
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game._game_tick(0,{});game.flow_preview=false;game.player.invulnerable=true
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.mission.objective_done.connect(func(id,index,total):events.append({"frame":frame,"event":"cut","id":id,"index":index,"total":total}))
 game.mission.objective_all.connect(func():events.append({"frame":frame,"event":"all"}))
 game.game_flow.state_changed.connect(func(value):events.append({"frame":frame,"event":"state","value":value}))
func pose(position:Vector3)->void:game.player.reset({"pos":position,"yaw":0},game.camera);game.player.invulnerable=true
func key(pressed:bool)->void:
 var event=InputEventKey.new();event.physical_keycode=KEY_E;event.pressed=pressed;Input.parse_input_event(event)
func expect(condition:bool,label:String)->void:
 checks+=1
 if not condition:failures.append({"frame":frame,"check":label})
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==1:pose(game.mission.extraction.pos)
 if frame in [40,240,460]:pose(game.mission.relays[{40:0,240:1,460:2}[frame]].o.pos+Vector3(0,0,1.3))
 if frame in [50,260,480]:key(true)
 if frame in [220,430,650]:key(false)
 if frame==700:pose(game.mission.extraction.pos)
 if frame==960:game.game_ui.buttons.redeploy.pressed.emit()
 game._game_tick(1.0/60,{"move":Vector2.ZERO,"fire":false});game._process(1.0/60)
 if frame==30:
  expect(game.game_flow.state=="playing" and game.mission.run.cut==0,"early extraction blocked")
  expect(game.game_ui.announcements.message.begins_with("Relays still live"),"early extraction message")
 if frame in [220,430,650]:expect(game.mission.run.cut=={220:1,430:2,650:3}[frame],"actual E interaction cut")
 if frame==680:
  expect(game.mission.run.allCut,"all relay flag")
  expect(game.game_ui.objective.text=="Get to the boat","extraction objective")
  expect(game.game_ui.navigation_hud.markers.size()==1 and game.game_ui.navigation_hud.markers[0].kind=="extract","boat-only marker")
 if frame==710:
  expect(game.game_flow.state=="complete" and not game.player.enabled and game.player.invulnerable,"actual extraction completion")
  expect(not game.game_ui.hud_on,"HUD logical gate closes at completion")
  debrief=game.mission.debrief.duplicate(true)
 if frame==750:expect(not game.game_ui.hud.visible and game.game_ui.hud.modulate.a==0,"HUD visually hidden after original .35s fade")
 if frame==930:
  expect(game.game_flow.menu=="complete" and game.game_ui.card.visible,"debrief menu after delay")
  expect(game.game_ui.buttons.has("redeploy"),"redeploy action exists")
 if frame==1100:
  expect(game.game_flow.state=="playing" and game.mission.run.cut==0 and not game.mission.run.allCut,"redeploy resets mission")
  expect(game.game_ui.status_hud.interaction.active==false,"redeploy clears prompt")
  finishing=true;call_deferred("finish")
 if frame in [100,320,540,680,710,930,1090]:call_deferred("capture",frame)
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/full-mission-%04d.png"%requested)
func finish()->void:
 var report={"frames":frame,"checks":checks,"failures":failures,"events":events,"debrief":debrief,"alive_enemies":game.enemy_manager.alive_count(),"scope":"Actual Main/GameFlow/UI: early extraction blocked, three physical E holds, live waves, extraction objective/marker, actual boat completion, delayed debrief and redeploy. Teleported starting poses and invulnerability; not from-spawn navigation or human play acceptance."}
 FileAccess.open("res://evidence/full-mission-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));key(false);game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
