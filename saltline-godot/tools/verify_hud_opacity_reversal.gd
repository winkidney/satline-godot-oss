extends SceneTree
class MissionProbe extends SaltlineMission:
 func _init()->void:player={"health":100.0,"max_health":100.0}
class WeaponProbe extends SaltlineWeapon:
 func _init()->void:slots={"rifle":{"mag_size":30,"ammo":30,"reserve":90},"pistol":{"mag_size":15,"ammo":15,"reserve":45}};rigs={"rifle":{},"pistol":{}}
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/transition-reversal-css.json"));var failures=[];var checks=0;var maximum=0.0;var names=[]
 for case in data.opacity:
  if case.className=="hud":continue
  var hud;var mission=MissionProbe.new();var weapon=WeaponProbe.new()
  match case.className:
   "h-prompt":hud=preload("res://scripts/interaction_hud.gd").new()
   "comms":hud=preload("res://scripts/radio_hud.gd").new()
   "loc-card":hud=preload("res://scripts/location_hud.gd").new()
   "h-msg":hud=preload("res://scripts/announcements_hud.gd").new()
   "h-health":hud=SaltlineStatusHud.new();hud.setup(mission,weapon)
  root.add_child(hud);names.append(case.className)
  for stage in case.stages:
   match case.className:
    "h-prompt":hud.set_prompt("Relay" if stage.on else null)
    "loc-card":hud.show_card(stage.on)
    "h-msg":hud.show_message("Message" if stage.on else "",999)
    "h-health":mission.player.health=80.0 if stage.on else 100.0
   var previous=0.0
   for sample in stage.samples:
    var dt=(sample.ms-previous)/1000.0;previous=sample.ms
    if case.className=="comms":hud.update_frame(dt,"Control",stage.on)
    elif case.className=="h-msg":hud.update_frame(dt,true)
    else:hud.update_frame(dt)
    var actual=float(hud.message_alpha if case.className=="h-msg" else hud.health_opacity if case.className=="h-health" else hud.alpha)
    var error=absf(actual-sample.alpha);maximum=maxf(maximum,error);checks+=1
    if error>1e-5:failures.append({"class":case.className,"on":stage.on,"ms":sample.ms,"actual":actual,"expected":sample.alpha})
  if case.className=="h-health":hud.dispose()
  hud.queue_free()
 var report={"controls":names,"checks":checks,"maximum_error":maximum,"failures":failures,"scope":"Five actual HUD controls against Chrome original opacity transitions, six interruptions each, including asymmetric health .12/.6 durations. Stub gameplay data for status only; no text/layout/GPU pixel or physical input proof."}
 FileAccess.open("res://evidence/hud-opacity-reversal-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await process_frame;quit(0 if failures.is_empty() else 1)
