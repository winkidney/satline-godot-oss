extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func matrix(value:Transform3D)->Array:return [value.basis.x.x,value.basis.x.y,value.basis.x.z,0.0,value.basis.y.x,value.basis.y.y,value.basis.y.z,0.0,value.basis.z.x,value.basis.z.y,value.basis.z.z,0.0,value.origin.x,value.origin.y,value.origin.z,1.0]
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/backdrop-motion-reference.json"));var source=game.source_scene
 source.update_backdrop_time(0);var index=0
 for frame in int(fixture.steps):
  var state="title" if frame<60 else "playing" if frame<240 else "paused" if frame<360 else "dead" if frame<540 else "playing"
  var dt=.2 if frame==400 else 0.0 if frame==401 else 1.0/60
  game.game_flow.state=state;game._process(dt)
  if index>=fixture.frames.size() or int(fixture.frames[index].frame)!=frame:continue
  var row=fixture.frames[index];index+=1
  if absf(source.backdrop_time-row.time)>.000001:failures.append("clock "+str(frame))
  for material in source.backdrop_materials:
   if absf(float(material.get_shader_parameter("source_backdrop_time"))-row.shader_time)>.00001:failures.append("shader clock "+str(frame))
  for key in fixture.ids:
   var node=source.source_nodes[fixture.ids[key]]
   if not source.backdrop_motion.has(key) or source.backdrop_motion[key]!=node:failures.append("binding "+key);continue
   var actual=matrix(node.transform)
   for channel in 16:
    checks+=1;var error=absf(actual[channel]-row.matrices[key][channel]);maximum=maxf(maximum,error)
    if error>.00001:failures.append("%d %s %d"%[frame,key,channel])
  if frame%60==0:await process_frame
 var before=source.backdrop_time
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path="";game.game_ui.save_path="";game.game_flow.start("mission",false,false,true)
 if source.backdrop_time!=before:failures.append("start reset backdrop time")
 game.game_flow.retry()
 if source.backdrop_time!=before:failures.append("retry reset backdrop time")
 var report={"checks":checks,"maximum_error":maximum,"samples":fixture.frames.size(),"failures":failures,"final_time":source.backdrop_time,"scope":fixture.scope}
 FileAccess.open("res://evidence/backdrop-motion-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
