extends SceneTree
class Game extends "res://scripts/main.gd":
 var pad_snapshot:Variant=null
 func _read_gamepad()->Variant:return pad_snapshot
var game
var frame=0
var failures=[]
var samples=[]
var finishing=false
var movement_start=Vector3.ZERO
var yaw_start=0.0
func _initialize()->void:call_deferred("setup")
func snapshot(axes:Array=[0,0,0,0],on:Dictionary={})->Dictionary:
 var buttons=[]
 for i in 20:buttons.append({"pressed":bool(on.get(i,0)>0),"value":float(on.get(i,0))})
 return {"axes":axes,"buttons":buttons}
func setup()->void:
 game=Game.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path="";game.game_ui.settings.sens=1;game.game_ui.settings.invertY=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.pad_snapshot=snapshot()
func expect(ok:bool,label:String)->void:
 if not ok:failures.append({"frame":frame,"check":label})
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==5:game.pad_snapshot=snapshot([0,0,0,0],{0:1})
 if frame==6:game.pad_snapshot=snapshot()
 if frame==10:game.player.invulnerable=true;game.enemy_manager.clear()
 if frame==170:movement_start=game.player.pos;yaw_start=game.player.yaw;game.pad_snapshot=snapshot([.5,-.8,.4,-.2],{10:1})
 if frame==171:game.pad_snapshot=snapshot([.5,-.8,.4,-.2])
 if frame==220:game.pad_snapshot=snapshot()
 if frame==235:game.pad_snapshot=snapshot([0,0,0,0],{6:1,7:1})
 if frame==276:game.pad_snapshot=snapshot()
 if frame==290:game.pad_snapshot=snapshot([0,0,0,0],{3:1})
 if frame==291:game.pad_snapshot=snapshot()
 if frame==320:
  expect(game.weapon.current=="pistol","Y switches weapon")
  game.player.reset({"pos":game.mission.relays[0].o.pos+Vector3(0,0,1.3),"yaw":0},game.camera);game.player.invulnerable=true
 if frame==335:game.pad_snapshot=snapshot([0,0,0,0],{2:1})
 if frame==500:game.pad_snapshot=snapshot()
 if frame==510:game.pad_snapshot=snapshot([0,0,0,0],{9:1})
 if frame==511:game.pad_snapshot=snapshot()
 if frame==520:game.pad_snapshot=snapshot([0,0,0,0],{13:1})
 if frame==521:game.pad_snapshot=snapshot()
 if frame==525:game.pad_snapshot=snapshot([0,0,0,0],{0:1})
 if frame==526:game.pad_snapshot=snapshot()
 if frame==550:game.pad_snapshot=snapshot([0,0,0,0],{1:1})
 if frame==551:game.pad_snapshot=snapshot()
 if frame==570:game.pad_snapshot=snapshot([0,0,0,0],{1:1})
 if frame==571:game.pad_snapshot=snapshot()
 if frame==590:game.pad_snapshot=null
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame==10:expect(game.game_flow.state=="intro","A deploy")
 if frame==160:expect(game.game_flow.state=="playing","intro completes")
 if frame==220:
  expect(game.player.pos.distance_to(movement_start)>.2,"left stick moves")
  expect(absf(game.player.yaw-yaw_start)>.05,"right stick turns")
 if frame==270:expect(game.weapon.shot_count>0 and game.weapon.ads>.5,"RT fires / LT aims")
 if frame==330:expect(game.game_ui.status_hud.interaction.active and game.game_ui.status_hud.interaction.key=="X","controller prompt label")
 if frame==505:expect(game.mission.run.cut==1 and not game.game_ui.status_hud.interaction.active,"X cuts relay")
 if frame==515:expect(game.game_flow.state=="paused","Start pauses")
 if frame==530:expect(game.game_ui.panel_open,"Dpad then A opens settings")
 if frame==560:expect(not game.game_ui.panel_open and game.game_flow.state=="paused","B closes settings")
 if frame==580:expect(game.game_flow.state=="playing","B resumes")
 if frame==600:expect(game.input_device=="kbm" and game.source_gamepad_input.held.is_empty(),"disconnect clears pad actions")
 if frame in [270,400,530]:call_deferred("capture",frame)
 if frame in [10,160,220,270,330,505,515,530,560,580,600]:samples.append({"frame":frame,"state":game.game_flow.state,"device":game.input_device,"weapon":game.weapon.current,"shots":game.weapon.shot_count,"cut":game.mission.run.cut,"panel":game.game_ui.panel_open})
 if frame==620:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/gamepad-%03d.png"%requested)
func finish()->void:
 expect(game.rumble_requests.size()>0,"fire requests rumble")
 var report={"frames":frame,"samples":samples,"rumble_requests":game.rumble_requests,"failures":failures,"scope":"Actual Main with browser-normalized pad snapshot injection: deploy, move/look, trigger fire/aim, switch, X relay, pause/settings/back/resume, disconnect and rumble requests. No physical device/SDL adapter/haptic motor acceptance or source full-frame pixels."}
 FileAccess.open("res://evidence/gamepad-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
