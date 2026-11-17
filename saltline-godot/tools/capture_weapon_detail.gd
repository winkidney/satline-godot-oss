extends SceneTree
var game
var frame=0
var finishing=false
var capture_tag="weapon-detail"
func _initialize()->void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--capture-tag="):capture_tag=argument.trim_prefix("--capture-tag=").validate_filename()
 call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{});game.flow_preview=false
 game.player.pos=Vector3(-11,0,-23);game.player.safe_pos=game.player.pos;game.player.yaw=-1.695;game.player.pitch=-.07
func _process(_delta:float)->bool:
 if game==null or finishing:return false
 frame+=1;var dt=1.0/60;var controls={"move":Vector2.ZERO,"sprint":false,"crouch":false,"jump":false,"interact":false,"fire":frame>=150 and frame<168,"ads":frame>=90 and frame<225,"reload":frame==250,"weapon2":frame==380,"weapon1":false,"swap":false}
 game.player.yaw=-1.695+.12*sin(frame/110.0);game._game_tick(dt,controls);game._process(dt)
 if frame>=600:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 var report={"frames":frame,"fps":60,"seconds":frame/60.0,"weapon":game.weapon.current,"wetness":game.source_scene.weapon_wetness,"engine":Engine.get_version_info(),"source_depth_24":ProjectSettings.get_setting("rendering/saltline/source_depth_24",false),"hardware_bias":game.source_scene.report.get("source_polygon_offset",{}),"scope":"Actual current source Main with six PAC detail patches, original lighting/IBL/post andreal weapon ADS/fire/reload/switch. Automated stationary warehouse preview, no enemies/audio. Fixed MovieMaker fps is not performance evidence."};FileAccess.open("res://evidence/"+capture_tag+"-capture.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit()
