extends SceneTree
func _initialize()->void:
 call_deferred("_verify")
func _verify()->void:
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_debris","id":"debris"}]}
 var instance=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.use_custom_data=true;instance.multimesh.mesh=BoxMesh.new();instance.multimesh.instance_count=256;scene.source_nodes={"debris":instance}
 var fx=SaltlineImpactEffects.new();root.add_child(fx);fx.camera=Camera3D.new();root.add_child(fx.camera)
 fx.physics=SaltlinePhysics.new({"boxes":[],"bounds":{}})
 var failures=[];var cases=[]
 for surface in ["rubber","dirt","glass"]:
  fx.pool=SaltlineParticles.new();fx.lit_pool=SaltlineParticles.new(1400,true);fx.debris=SaltlineDebris.new(scene)
  fx.impact({"point":Vector3(0,1,-3),"normal":Vector3.UP,"surface":surface},Vector3.DOWN)
  var expected=[12,1,4] if surface=="glass" else [0,5,3]
  var actual=[fx.pool.emitted,fx.lit_pool.emitted,fx.debris.emitted]
  if actual!=expected:failures.append("source emission configuration "+surface)
  cases.append({"surface":surface,"add":actual[0],"lit":actual[1],"debris":actual[2]})
  if surface=="glass":
   for p in fx.pool.particles:
    if p.mode!=1 or p.frame!=6 or p.flags!=2 or p.ramp!=3:failures.append("glass shard configuration")
 var report={"failures":failures,"cases":cases,"source":"Active impact material branches, lines 59345-59470"}
 var file=FileAccess.open("res://evidence/impact-surfaces-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));fx.camera.queue_free();fx.queue_free();instance.free();scene.free();quit(0 if failures.is_empty() else 1)
