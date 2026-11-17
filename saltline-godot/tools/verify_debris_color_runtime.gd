extends SceneTree
func _initialize()->void:call_deferred("verify")
func verify()->void:
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_debris","id":"test"}]}
 var instance=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.use_custom_data=true;instance.multimesh.mesh=BoxMesh.new();instance.multimesh.instance_count=4;scene.source_nodes={"test":instance};root.add_child(instance)
 var pool=SaltlineDebris.new(scene);var colors=[Vector3(.6,.2,.05),Vector3(.62,.5,.33),Vector3(.2,.21,.23),Vector3(.42,.41,.39)]
 for color in colors:pool.emit(Vector3.ZERO,Vector3.ZERO,Vector3.ONE,color,3,0)
 pool.update(0);await process_frame;RenderingServer.force_draw(false)
 var failures=[];var checks=0;var maximum=0.0
 for i in colors.size():
  var actual=instance.multimesh.get_instance_custom_data(i)
  for k in 3:
   checks+=1;var error=abs(float(actual[k])-float(pool.slots[i].color[k]));maximum=maxf(maximum,error)
   if not is_finite(error) or error>1e-7:failures.append({"slot":i,"channel":k,"error":error})
 var report={"checks":checks,"maximum_error":maximum,"failures":failures,"scope":"Real RenderingDevice MultiMesh custom-data API readback against CPU tint driving debris write, four colors. No shaded-pixel comparison."}
 FileAccess.open("res://evidence/debris-color-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));instance.free();scene.free();quit(0 if failures.is_empty() else 1)
