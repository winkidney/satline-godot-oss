extends SceneTree
var failures=[]
var checks=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message)
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var solver=load("res://scripts/source_physics.gd").new(data.physics)
 var player=load("res://scripts/player.gd").new(data.modules.player,solver)
 player.enabled=true;player.alive=true;player.yaw=0;player.pitch=0;player.ads=0
 var mouse=load("res://scripts/source_mouse_input.gd").new()
 check(mouse.motion(100,-50,1,false),"valid mouse movement")
 check(mouse.motion(-20,10,1,false),"second movement accumulates")
 check(not mouse.motion(401,0,1,false),"raw spike rejects entire event")
 var look=mouse.consume()
 check(absf(look.dx-.168)<1e-14 and absf(look.dy+.084)<1e-14,"original hE=.0021 and accumulation")
 player.look_normalized(look.dx,look.dy)
 check(absf(player.yaw+.168)<1e-14 and absf(player.pitch-.084)<1e-14,"hip camera original signs")
 check(mouse.consume()=={"dx":0.0,"dy":0.0},"look consumed exactly once")
 mouse.motion(400,400,1.25,true);look=mouse.consume()
 check(absf(look.dx-1.05)<1e-14 and absf(look.dy+1.05)<1e-14,"400 boundary, sensitivity and inversion")
 player.ads=1;player.yaw=0;player.pitch=0;player.look_normalized(1.0,0)
 check(absf(player.yaw+float(player.tuning.adsLook))<1e-14,"ADS scale")
 player.ads=0;player.yaw=PI*4+.1;player.look_normalized(0,100)
 check(absf(player.yaw-.1)<1e-12 and player.pitch==-player.tuning.pitchLimit,"positive yaw wrap and pitch clamp")
 player.yaw=-PI*4-.1;player.look_normalized(0,-100)
 check(absf(player.yaw+.1)<1e-12 and player.pitch==player.tuning.pitchLimit,"negative signed remainder")
 player.enabled=false;var yaw=player.yaw;player.look_normalized(1,1)
 check(player.yaw==yaw,"disabled camera")
 check(not mouse.wheel(279,1) and mouse.wheel(280,1),"wheel initial exact 280ms boundary")
 check(not mouse.wheel(559,1) and mouse.wheel(560,-1),"wheel either direction and cooldown")
 check(not mouse.wheel(840,0) and mouse.wheel(840,1),"zero wheel does not consume cooldown")
 mouse.motion(10,20,1,false);mouse.clear()
 check(mouse.consume()=={"dx":0.0,"dy":0.0},"pause/state reset clears look")
 check(load("res://scripts/main.gd")!=null,"production Main parses with input bridge")
 var report={"checks":checks,"failures":failures,"scope":"Actual native input accumulator and player look, source mouse gain/spike/ADS/sign/wrap/wheel cooldown; Main parse only. Native wheel notch units differ from browser pixel deltaY; no real OS pointer event acceptance proof."}
 FileAccess.open("res://evidence/source-mouse-input-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
