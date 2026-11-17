extends SceneTree
func _initialize()->void:
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/scenes/main.json"))
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/ground-metal-observed.json"))
 var query=preload("res://scripts/ground_queries.gd").new(source)
 var checks=0;var failures=[];var metal_count=0
 for row in fixture.rows:
  var x=query.decode_f64(row.x_f64);var z=query.decode_f64(row.z_f64)
  var surface=query.ground_surface_at(x,z);checks+=2
  if surface=="metal":metal_count+=1
  if (surface=="metal")!=row.metal or surface!=row.surface:
   if failures.size()<30:failures.append({"point":[x,z],"actual":surface,"expected":row.surface})
 checks+=1
 if query.metal_rects.size()!=55:failures.append("rect count")
 var report={"rects":query.metal_rects.size(),"points":fixture.rows.size(),"checks":checks,"metal_points":metal_count,"failures":failures,"source_sha256":fixture.source_sha256,"instrumented_response_sha256":fixture.instrumented_response_sha256,"scope":"Original live uw.k and level.groundSurfaceAt, default4207/high, 55 baked rects. Grid and exact/epsilon rectangle edges, f64 lossless coordinates/bounds. No other seeds or player movement/pixel proof."}
 FileAccess.open("res://evidence/ground-metal-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
