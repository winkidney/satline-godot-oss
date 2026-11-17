extends SceneTree
func _initialize()->void:
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_decals","id":"test"}]}
 var instance=MeshInstance3D.new();var quad=QuadMesh.new();quad.material=StandardMaterial3D.new();instance.mesh=quad;scene.source_nodes={"test":instance}
 var pool=load("res://scripts/decals.gd").new(scene)
 var failures=[]
 pool.impact({"point":Vector3.ZERO,"normal":Vector3.UP,"surface":"water"})
 if pool.emitted!=0:failures.append("water must not create bullet decals")
 pool.impact({"point":Vector3(1,2,3),"normal":Vector3.RIGHT,"surface":"metal"})
 if pool.slots[0].kind!="bullet_metal":failures.append("surface selection")
 var plane_error=0.0
 for vertex in pool.slots[0].positions:plane_error=maxf(plane_error,absf(vertex.x-1.004))
 if plane_error>.00001:failures.append("surface offset and coplanarity")
 var uv:Vector4=pool.slots[0].uv
 if uv.y<.5 or uv.w>1 or uv.x<0 or uv.z>.5:failures.append("metal atlas tiles with padding")
 for i in 169:pool.add(Vector3(i,0,0),Vector3.UP,"bullet_concrete")
 if pool.slots.size()!=160 or pool.next!=10:failures.append("160 slot ring overwrite")
 for i in 14:
  if absf(pool.slots[(pool.next+i)%160].alpha-float(i+1)/15)>.00001:failures.append("oldest decal fade")
 var arrays=instance.mesh.surface_get_arrays(0)
 if arrays[Mesh.ARRAY_VERTEX].size()!=640 or arrays[Mesh.ARRAY_INDEX].size()!=960:failures.append("batched mesh capacity")
 var report={"failures":failures,"plane_error":plane_error,"emitted":pool.emitted,"capacity":pool.slots.size(),"old_fade_slots":14,"vertices":arrays[Mesh.ARRAY_VERTEX].size()}
 var file=FileAccess.open("res://evidence/decal-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify(report));instance.free();scene.free();quit(0 if failures.is_empty() else 1)
