extends SceneTree
func _initialize()->void:call_deferred("verify")
func verify()->void:
 root.size=Vector2i(1280,720);var camera=Camera3D.new();root.add_child(camera);camera.fov=74;camera.near=.08;camera.far=900;camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.make_current()
 var cases=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/showcase-camera-reference.json"));var maximum=0.0;var failures=[];var checks=0
 for test in cases:
  camera.position=Vector3(test.position[0],test.position[1],test.position[2]);camera.look_at(Vector3(test.target[0],test.target[1],test.target[2]))
  for point in test.points:
   var actual=camera.unproject_position(Vector3(point.world[0],point.world[1],point.world[2]))
   for k in 2:
    checks+=1;var error=absf(actual[k]-point.screen[k]);maximum=maxf(maximum,error)
    if error>.001:failures.append({"mode":test.mode,"error":error})
 var report={"checks":checks,"maximum_pixel_error":maximum,"failures":failures,"scope":"Bundled THREE74deg showcase cameras vs Godot unprojection of36 world markers at1280x720; no lighting or full image test."}
 FileAccess.open("res://evidence/showcase-camera-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));camera.queue_free();quit(0 if failures.is_empty() else 1)
