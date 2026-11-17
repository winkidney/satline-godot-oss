extends SceneTree
var messages=[]
var rescued=0
var failures=[]
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 await process_frame;RenderingServer.force_draw(false)
 game.mission.message.connect(func(text,seconds):messages.append({"text":text,"seconds":seconds}))
 game.player.motion_event.connect(func(kind,_payload):
  if kind=="rescued":rescued+=1
 )
 var rows=[]
 for entry in [["playing",100.0,true],["title",100.0,false],["playing",8.0,false]]:
  game._reset_session("mission",false);game.mission.state=entry[0]
  game.player.health=entry[1];game.player.invulnerable=false
  game.game_ui.announcements.clear();messages.clear()
  var before=rescued
  game.player.pos=Vector3(32,-5,6);game.player.on_ground=false
  game.player.update(1.0/60,{"move":Vector2.ZERO,"ads":false,"fire":false,"jump":false,"crouch":false,"sprint":false},game.camera)
  if rescued!=before+1:failures.append("actual rescue event absent "+str(entry))
  if bool(entry[2]):
   if messages!=[{"text":"Hauled out of the water","seconds":2.5}]:failures.append("playing rescue message")
   if game.game_ui.announcements.message!="Hauled out of the water" or game.game_ui.announcements.message_remaining!=2.5:failures.append("message not delivered to actual HUD")
  elif not messages.is_empty():failures.append("message outside living gameplay "+str(entry))
  if game.player.health!=maxf(0,float(entry[1])-12):failures.append("rescue damage changed")
  rows.append({"initial_state":entry[0],"initial_health":entry[1],"final_state":game.mission.state,"health":game.player.health,"messages":messages.duplicate(true)})
 var report={"failures":failures,"cases":rows,"rescues":rescued,"source":"bundle-1.js:85478-85479","scope":"Actual Main player.update, original collision and rescue damage/event ordering, existing mission message to GameUI announcement; playing, non-playing and lethal rescue."}
 FileAccess.open("res://evidence/rescue-message-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
