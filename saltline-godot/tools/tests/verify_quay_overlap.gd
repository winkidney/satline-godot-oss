extends SceneTree

func _initialize()->void:call_deferred("_run")

func _run()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source()
 if not scene.source_nodes.has("5dfeee22-f3fa-40b6-9f7f-1202fd0686e5") or not scene.geometry_records.has("2f646d8b-232d-4329-9355-48f6768c0c27"):
  push_error("Quay wall source is missing");scene.queue_free();await process_frame;quit(1);return
 var node:MeshInstance3D=scene.source_nodes["5dfeee22-f3fa-40b6-9f7f-1202fd0686e5"]
 var geometry:Dictionary=scene.geometry_records["2f646d8b-232d-4329-9355-48f6768c0c27"]
 var original:PackedVector3Array=scene._vec3(geometry.attributes.position)
 var actual:PackedVector3Array=node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 if actual.size()!=original.size():
  push_error("Quay wall vertex count changed");scene.queue_free();await process_frame;quit(1);return
 var corners=0;var unseparated=0;var changed_elsewhere=0
 for i in original.size():
  var p=original[i];var q=actual[i]
  var corner=is_equal_approx(p.x,30.0) and (is_equal_approx(p.y,-.002) or is_equal_approx(p.y,-.67)) and (is_equal_approx(p.z,-30.97) or is_equal_approx(p.z,19.55))
  if corner:
   corners+=1
   if not (q.x>30.003 and q.x<30.01 and is_equal_approx(q.y,p.y) and is_equal_approx(q.z,p.z)):unseparated+=1
  elif not p.is_equal_approx(q):changed_elsewhere+=1
 var passed=node.visible and corners==24 and unseparated==0 and changed_elsewhere==0
 print(JSON.stringify({"corners":corners,"unseparated":unseparated,"changed_elsewhere":changed_elsewhere,"passed":passed}))
 scene.queue_free();await process_frame;quit(0 if passed else 1)
