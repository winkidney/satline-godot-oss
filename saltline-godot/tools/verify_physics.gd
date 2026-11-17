extends SceneTree
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var solver=load("res://scripts/source_physics.gd").new(data.physics)
 var cases=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/physics-source-fixtures.json"))
 var error=0.0;var failures=0
 for c in cases:
  var result=solver.move_capsule(Vector3(c.pos[0],c.pos[1],c.pos[2]),Vector3(c.vel[0],c.vel[1],c.vel[2]),c.dt,c.height,c.ground)
  var expected=Vector3(c.position[0],c.position[1],c.position[2]);var velocity=Vector3(c.velocity[0],c.velocity[1],c.velocity[2])
  var difference=maxf(result.position.distance_to(expected),result.velocity.distance_to(velocity));error=maxf(error,difference)
  if difference>.0001 or result.on_ground!=c.on_ground or result.hit_wall!=c.hit_wall or result.hit_ceil!=c.hit_ceil:failures+=1
 var report={"source_cases":cases.size(),"failures":failures,"max_error":error,"tolerance":.0001}
 var f=FileAccess.open("res://evidence/physics-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print(JSON.stringify(report));quit(1 if failures else 0)
