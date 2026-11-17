extends SceneTree
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var solver=load("res://scripts/source_physics.gd").new(data.physics)
 var player=load("res://scripts/player.gd").new(data.modules.player,solver)
 var camera=Camera3D.new();root.add_child(camera)
 var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":false,"fire":false,"jump":false}
 var failures=[]
 for i in 120:player.update(1.0/60,input,camera)
 if absf(player.pos.y)>.0001 or not player.on_ground:failures.append("ground support")
 input.jump=true;player.update(1.0/60,input,camera);input.jump=false
 var apex=player.pos.y
 for i in 90:player.update(1.0/60,input,camera);apex=maxf(apex,player.pos.y)
 if absf(apex-1)>.02 or not player.on_ground:failures.append("jump apex or landing")
 input.crouch=true
 for i in 60:player.update(1.0/60,input,camera)
 if absf(player.eye_height-1.05)>.001:failures.append("crouch eye")
 input.crouch=false;input.ads=true
 for i in 90:player.update(1.0/60,input,camera)
 if absf(player.fov-52)>.001 or absf(camera.fov-player.fov)>.010001:failures.append("ADS field of view")
 input.ads=false
 for i in 90:player.update(1.0/60,input,camera)
 input.move=Vector2(0,1);input.sprint=true
 for i in 30:player.update(1.0/60,input,camera)
 if absf(player.speed-6.4)>.001:failures.append("sprint acceleration")
 var report={"failures":failures,"fov_scope":"Internal smooth FOV must reach target within .001; Camera3D is updated only when discrepancy exceeds existing .01 threshold.","jump_apex_m":apex,"sprint_speed_m_s":player.speed,"checks":["ground support","jump and landing","crouch eye","ADS field of view","sprint acceleration"]}
 var f=FileAccess.open("res://evidence/player-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print(JSON.stringify(report));camera.queue_free();quit(0 if failures.is_empty() else 1)
