extends "res://tools/verify_ground_runtime.gd"
var metal_checks=0
func setup()->void:
 super.setup()
 var saved_position=game.player.pos;var saved_surface=game.player.ground_surface
 for rect in game.ground_queries.metal_rects:
  game.player.pos=Vector3((rect[0]+rect[2])*.5,2,(rect[1]+rect[3])*.5)
  game.player.ground_surface="concrete";metal_checks+=1
  if game.player.event_surface()!="metal":failures.append("Main player did not resolve original metal rectangle")
  game.player.ground_surface="wood";metal_checks+=1
  if game.player.event_surface()!="wood":failures.append("Main player ignored explicit contact priority")
 game.player.pos=saved_position;game.player.ground_surface=saved_surface
func finish()->void:
 var report={"frames":frame,"metal_checks":metal_checks,"failures":failures,"scope":"Actual Main-bound Player resolver at55 metal rectangle centers and wood contact override, followed by existing240-frame real wet-step/wet-land/dry-land and impact-decal routing regression. Static metal probes at height2, no entire original metal movement trajectory or pixels."}
 FileAccess.open("res://evidence/ground-metal-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await super.finish()
