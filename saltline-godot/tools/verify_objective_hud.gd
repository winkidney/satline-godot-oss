extends SceneTree
func _initialize()->void:
 var hud=preload("res://scripts/objective_hud.gd").new()
 # Observed from original __G.hud.setObjective/update and .h-obj-t.textContent.
 var rows=[["",0.0,""],["Cut the three uplink relays",0.0,""],["Cut the three uplink relays",.01,""],["Cut the three uplink relays",.02,"C"],["Cut the three uplink relays",.1,"Cut t"],["Cut the three uplink relays",1.0,"Cut the three uplink relays"],["Get to the boat",.05,"Ge"],["Get to the boat",.05,"Get "],["",0.0,""],["Get to the boat",.1,"Get "]]
 var failures=[];var checks=0
 for row in rows:
  hud.update_frame(row[1],row[0],0,3);checks+=1
  if hud.text.left(hud.characters)!=row[2]:failures.append({"row":row,"actual":hud.text.left(hud.characters)})
 var ui=load("res://scripts/game_ui.gd").new();ui.objective=hud;ui.announcements=load("res://scripts/announcements_hud.gd").new();ui.status_hud=SaltlineStatusHud.new();ui.status_hud.interaction=load("res://scripts/interaction_hud.gd").new();ui._reset_hud();checks+=1
 if not hud.text.is_empty() or hud.characters!=0:failures.append("HUD reset retained objective progress")
 checks+=1
 if ui._score_text(1234567)!="1,234,567":failures.append("holdout score grouping")
 var report={"checks":checks,"failures":failures,"scope":"Ten original-browser observed typewriter states; actual GameUI HUD reset and holdout score grouping. No CSS pixel equality assertion."}
 FileAccess.open("res://evidence/objective-hud-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));ui.status_hud.interaction.free();ui.status_hud.free();ui.announcements.free();ui.free();hud.free();quit(0 if failures.is_empty() else 1)
