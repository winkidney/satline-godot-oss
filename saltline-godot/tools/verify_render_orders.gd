extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/node-render-order-bindings.json"));var failures=[];var checks=0;var nonzero=[]
 for record in reference.bindings:
  var node=game.source_scene.source_nodes[record.id]
  if not node is GeometryInstance3D:continue
  var expected=int(record.renderOrder)
  if expected==-1000:expected=-128
  elif expected==890:expected=99
  elif expected==900:expected=100
  for material in game.source_ibl_service._materials(node):
   checks+=1
   if material.render_priority!=expected:failures.append({"node":record.id,"expected":expected,"actual":material.render_priority})
  if record.renderOrder!=0:nonzero.append({"name":record.name,"materials":record.material_names,"source":record.renderOrder,"native":expected})
 await process_frame;RenderingServer.force_draw(false)
 var report={"checks":checks,"nonzero":nonzero,"failures":failures,"scope":"Actual Main geometry material priorities vs structurally verified original node order. Extreme sky/rain values preserve relative order through existing native compression. Not full overlap-pixel/sorting parity or unsupported nonzero groupOrder."}
 FileAccess.open("res://evidence/render-order-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
