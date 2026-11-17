extends SceneTree
func _initialize()->void:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/navigation-reference.json"))
 var physics=SaltlinePhysics.new(source.physics);var nav=load("res://scripts/navigation.gd").new(physics);nav.rebuild()
 var failures=[];var mismatches=0;var max_error=0.0
 for i in nav.blocked.size():
  if nav.blocked[i]!=fixture.blocked[i]:mismatches+=1
 if mismatches:failures.append("blocked cells differ: %d"%mismatches)
 for i in fixture.cases.size():
  var test:Dictionary=fixture.cases[i]
  var start=Vector3(test.start[0],0,test.start[2]);var goal=Vector3(test.end[0],0,test.end[2])
  var path=nav.find_path(start,goal)
  if nav.clear_line(start,goal)!=test.clear:failures.append("clear line %d"%i)
  if (path==null)!=(test.path==null):failures.append("reachability %d"%i);continue
  if path==null:continue
  if path.size()!=test.path.size():failures.append("waypoint count %d"%i);continue
  for j in path.size():
   var expected=Vector3(test.path[j][0],0,test.path[j][2]);var error=path[j].distance_to(expected);max_error=maxf(max_error,error)
   if error>.0001:failures.append("waypoint %d:%d"%[i,j])
 var before=nav.blocked.duplicate()
 physics.boxes.clear();nav.is_walkable(0,0)
 if nav.blocked==before:failures.append("dynamic obstacle rebuild")
 var report={"failures":failures,"grid_cells":fixture.blocked.size(),"grid_mismatches":mismatches,"paths":fixture.cases.size(),"max_waypoint_error":max_error,"dynamic_rebuild":true}
 var file=FileAccess.open("res://evidence/navigation-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
