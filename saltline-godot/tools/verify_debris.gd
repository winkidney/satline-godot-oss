extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/debris-reference.json"))
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_debris","id":"test"}]}
 var instance=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.use_custom_data=true;instance.multimesh.mesh=BoxMesh.new();instance.multimesh.instance_count=4
 scene.source_nodes={"test":instance}
 var pool=load("res://scripts/debris.gd").new(scene)
 for c in fixture.cases:
  pool.emit(Vector3(c.position[0],c.position[1],c.position[2]),Vector3(c.velocity[0],c.velocity[1],c.velocity[2]),Vector3(c.size[0],c.size[1],c.size[2]),Vector3(c.color[0],c.color[1],c.color[2]),c.life,c.floor)
  var slot:Dictionary=pool.slots[pool.next-1]
  slot.axis=Vector3(c.axis[0],c.axis[1],c.axis[2]);slot.angle=c.angle;slot.spin=c.spin
 var failures=[];var maximum=0.0;var fields=0
 for frame in fixture.frames.size():
  pool.update(1.0/60)
  var expected:Dictionary=fixture.frames[frame]
  if pool.live!=expected.live:failures.append("live count frame %d"%frame)
  for i in 2:
   if pool.slots[i].state!=expected.state[i]:failures.append("state frame %d instance %d"%[frame,i])
   var matrix:Transform3D=pool.transforms[i]
   var actual=[matrix.basis.x.x,matrix.basis.x.y,matrix.basis.x.z,0,matrix.basis.y.x,matrix.basis.y.y,matrix.basis.y.z,0,matrix.basis.z.x,matrix.basis.z.y,matrix.basis.z.z,0,matrix.origin.x,matrix.origin.y,matrix.origin.z,1]
   for j in 16:
    var difference=absf(float(actual[j])-float(expected.matrix[i*16+j]));maximum=maxf(maximum,difference);fields+=1
    if difference>.0001:failures.append("matrix frame %d instance %d field %d"%[frame,i,j])
 var report={"failures":failures,"frames":fixture.frames.size(),"fields_compared":fields,"max_matrix_error":maximum,"bounces":pool.bounces,"settled":pool.settled,"remaining":pool.live,"random_alignment":"Only initial axis, angle and spin aligned to original random values"}
 var file=FileAccess.open("res://evidence/debris-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first_failures":failures.slice(0,5),"max_matrix_error":maximum,"frames":fixture.frames.size(),"fields_compared":fields}));instance.free();scene.free();quit(0 if failures.is_empty() else 1)
