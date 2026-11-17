extends SceneTree

class MissionProbe extends SaltlineMission:
 func _init(avatar:SaltlinePlayer)->void:
  player=avatar;run={"allCut":false};extraction={};relays=[{"cut":false,"short":"A","o":{"pos":Vector3(5,0,-10)}}]
class WeaponProbe extends SaltlineWeapon:
 func _init()->void:pass

func _initialize()->void:call_deferred("runtime" if "--runtime" in OS.get_cmdline_user_args() else "run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/navigation-transition-css.json"))
 var collision=SaltlinePhysics.new({"bounds":{},"boxes":[]});var avatar=SaltlinePlayer.new({"tuning":{},"pos":[0,0,0],"yaw":0},collision)
 var mission=MissionProbe.new(avatar);var weapon=WeaponProbe.new();var camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,1.68,4);camera.fov=74
 var hud=SaltlineNavigationHud.new();root.add_child(hud);hud.setup(mission,camera,weapon)
 root.size=Vector2i(1280,720)
 var failures=[];var comparisons=0;var maximum_alpha_error=0.0;var maximum_gap_error=0.0
 for stage in reference.stages:
  var input=stage.input;avatar.ads=float(input.ads);avatar.alive=input.get("alive",true);avatar.sprinting=input.get("sprinting",false);weapon.state=input.get("state","idle");weapon.spread=float(input.spread)
  mission.relays[0].o.pos={"normal":Vector3(5,0,-10),"dim":Vector3(0,0,-10),"offscreen":Vector3(35,0,-10),"near":Vector3(0,0,-1)}[input.marker]
  var previous=0.0
  for sample in stage.samples:
   hud.update_frame((float(sample.ms)-previous)/1000.0);previous=float(sample.ms)
   var actual={"cross_alpha":hud.cross.alpha,"gap":hud.cross.gap,"marks_alpha":hud.marks_fade.value,"marker_alpha":hud.markers[0].alpha}
   for key in actual:
    var error=absf(float(actual[key])-float(sample[key]));comparisons+=1
    if key=="gap":maximum_gap_error=maxf(maximum_gap_error,error)
    else:maximum_alpha_error=maxf(maximum_alpha_error,error)
    if error>(.0001 if key=="gap" else .00001):failures.append({"input":input,"ms":sample.ms,"key":key,"expected":sample[key],"actual":actual[key]})
 for state in reference.initial_markers:
  mission.relays[0].o.pos={"normal":Vector3(5,0,-10),"dim":Vector3(0,0,-10),"offscreen":Vector3(35,0,-10),"near":Vector3(0,0,-1)}[state]
  mission.hud_reset.emit();hud.update_frame(0)
  if absf(hud.markers[0].alpha-float(reference.initial_markers[state].alpha))>.00001:failures.append("new marker first computed opacity "+state)
 mission.relays[0].o.pos=Vector3(5,0,-10);mission.hud_reset.emit();hud.update_frame(0)
 mission.relays[0].o.pos=Vector3(0,0,-10);hud.update_frame(.05)
 mission.relays.append({"cut":false,"short":"B","o":{"pos":Vector3(5,0,-10)}});hud.update_frame(0)
 if absf(hud.markers[0].alpha-.22)>.00001 or hud.marker_transitions.size()!=2:failures.append("rebuilt marker list retained interrupted alpha")
 mission.hud_reset.emit()
 if not hud.marker_transitions.is_empty():failures.append("mission reset retained marker transitions")
 mission.relays.clear();hud.update_frame(0)
 if not hud.marker_transitions.is_empty():failures.append("removed marker kept transition state")
 var report={"initial_marker_cases":reference.initial_markers.size(),"marker_reset_checks":3,"stages":reference.stages.size(),"comparisons":comparisons,"maximum_alpha_error":maximum_alpha_error,"maximum_gap_error":maximum_gap_error,"failures":failures,"scope":reference.scope+" Native actual NavigationHud.update_frame; projection and drawing unchanged except animated alpha/gap. Marker transition removal checked."}
 FileAccess.open("res://evidence/navigation-transition-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));hud.free();camera.free();quit(0 if failures.is_empty() else 1)

func runtime()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/navigation-transition-css.json"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true);game.enemy_manager.clear()
 game.game_flow.fade=0;game.game_flow.state="playing";game.player.enabled=false;game.player.pos=Vector3.ZERO
 game.camera.position=Vector3(0,1.68,4);game.camera.rotation=Vector3.ZERO;game.camera.fov=74
 game.game_ui.hud_opacity_transition.reset(1);game.game_ui.hud.modulate.a=1
 game.mission.relays=[{"cut":false,"short":"A","o":{"pos":Vector3(5,0,-10)}}]
 game._process(0)
 var hud=game.game_ui.navigation_hud
 hud.cross_fade.reset(1);hud.marks_fade.reset(1);hud.gap_transition=hud._new_transition(0,.06,Vector4(0,0,1,1));hud.marker_transitions.clear()
 var failures=[];var comparisons=0;var maximum_alpha_error=0.0;var maximum_gap_error=0.0;var stage_index=0;var captures=[]
 for stage in reference.stages:
  var input=stage.input;game.player.ads=float(input.ads);game.player.alive=input.get("alive",true);game.player.sprinting=input.get("sprinting",false);game.weapon.state=input.get("state","idle");game.weapon.spread=float(input.spread)
  game.mission.relays[0].o.pos={"normal":Vector3(5,0,-10),"dim":Vector3(0,0,-10),"offscreen":Vector3(35,0,-10),"near":Vector3(0,0,-1)}[input.marker]
  var previous=0.0
  for sample in stage.samples:
   game.game_flow.state="playing";game.game_ui.update_frame((float(sample.ms)-previous)/1000.0,game.animation_time);previous=float(sample.ms)
   var actual={"cross_alpha":hud.cross.alpha,"gap":hud.cross.gap,"marks_alpha":hud.marks_fade.value,"marker_alpha":hud.markers[0].alpha}
   for key in actual:
    var error=absf(float(actual[key])-float(sample[key]));comparisons+=1
    if key=="gap":maximum_gap_error=maxf(maximum_gap_error,error)
    else:maximum_alpha_error=maxf(maximum_alpha_error,error)
    if error>(.0001 if key=="gap" else .00001):failures.append({"stage":stage_index,"ms":sample.ms,"key":key,"actual":actual[key],"expected":sample[key]})
   if stage_index in [0,3,5,6] and float(sample.ms)==float(stage.samples[1].ms):
    await process_frame;RenderingServer.force_draw(false)
    var path="res://evidence/navigation-transition-runtime-%02d.png"%stage_index;root.get_texture().get_image().save_png(path);captures.append({"path":path,"sample":actual})
  stage_index+=1
 var report={"stages":stage_index,"comparisons":comparisons,"maximum_alpha_error":maximum_alpha_error,"maximum_gap_error":maximum_gap_error,"captures":captures,"failures":failures,"navigation_sha256":FileAccess.get_sha256("res://scripts/navigation_hud.gd"),"game_ui_sha256":FileAccess.get_sha256("res://scripts/game_ui.gd"),"scope":"Actual Main/GameUI/NavigationHud calls against original Chrome CSS samples and4 real GPU captures, controlled gameplay data and CSS-initial fixture state. Full HUD pixels, physical ADS input and world gameplay remain separate."}
 FileAccess.open("res://evidence/navigation-transition-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
