extends SceneTree
var game
var frame=0
var pause_timer=0.0
var failures=[]
var finishing=false
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.player.invulnerable=true;game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==30:game.game_ui._warning("Machines inbound",3)
 if frame==60:game.game_ui._message("Relay cut — two remaining",2)
 if frame==120:pause_timer=game.game_ui.announcements.warning_remaining;game.game_flow.pause()
 if frame==179 and game.game_ui.announcements.warning_remaining!=pause_timer:failures.append("hidden HUD warning timer advanced")
 if frame==180:game.game_flow.resume()
 game._game_tick(1.0/60,{});game._process(1.0/60)
 if frame==45 and not game.game_ui.announcements.warning_on:failures.append("warning not active after trigger")
 if frame==90 and (not game.game_ui.announcements.message_target or game.game_flow.state!="playing" or game.game_flow.fade>.01):failures.append("message not active in visible playing scene")
 if frame in [45,90,200]:call_deferred("capture",frame)
 if frame==360:
  finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/announcements-%03d.png"%requested)
func finish()->void:
 var hud=game.game_ui.announcements
 if hud.warning_on or hud.message_target or hud.message_alpha!=0:failures.append("announcements did not expire")
 var report={"frames":frame,"failures":failures,"scope":"Actual Main warning/message, pause timer gate, resume and expiry; controlled triggers, no source whole-frame/pixel equality"}
 FileAccess.open("res://evidence/announcements-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
