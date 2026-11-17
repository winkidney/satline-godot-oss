extends SceneTree
var game
var frame=0
var finishing=false
var ready=false
var output_dir="/tmp/saltline-backdrop-frames"
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.fade=0
 DirAccess.make_dir_recursive_absolute(output_dir)
 await process_frame;ready=true
func _process(_dt:float)->bool:
 if not ready or game==null or finishing:return false
 frame+=1
 var position=Vector3(27,1.7,27);var target=Vector3(31.5,-.3,21);var fov=60.0
 if frame>120:position=Vector3(35,30,-52);target=Vector3(41,28.08,-56.7);fov=45
 elif frame>60:position=Vector3(35.5,23,7);target=Vector3(41,20.7,0);fov=60
 game.camera.global_position=position;game.camera.look_at(target,Vector3.UP);game.camera.fov=fov;game.camera.make_current();game.view_camera.cull_mask=0;game.game_ui.root.visible=false
 game._process(1.0/30);game.game_ui.root.visible=false
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(output_dir+"/frame-%04d.png"%frame)
 if frame>=180:finishing=true;call_deferred("finish")
 return false
func finish()->void:
 var report={"frames":frame,"fps":30,"frame_directory":output_dir,"backdrop_time":game.source_scene.backdrop_time,"takes":["boat","spreader","radar"],"scope":"Actual native Main rendering, fixed30Hz forced GPU frame readback; three inspection cameras and hidden HUD/viewmodel, title state so backdrop advances without gameplay. Not original camera parity or real-time performance."}
 FileAccess.open("res://evidence/backdrop-motion-recording.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit()
