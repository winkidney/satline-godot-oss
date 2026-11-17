extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var content=preload("res://scripts/control_content.gd").new();root.add_child(content);var failures=[];var samples=[]
 for width in [382,262,200]:
  content.size.x=width;content.reflow(width)
  if content.row_count!=30:failures.append("source row count")
  var keys=0;var headings=0
  for op in content.operations:
   if op.kind=="box":keys+=1
   if op.kind=="text" and op.font=="heading":headings+=1
  if headings!=3 or keys!=int(content.source.key_count) or content.custom_minimum_size.y<700:failures.append("rich controls missing")
  samples.append({"width":width,"height":content.custom_minimum_size.y,"rows":content.row_count,"key_boxes":keys,"headings":headings,"draw_operations":content.operations.size()})
 if samples[1].height<=samples[0].height:failures.append("notes did not wrap on narrow content")
 var report={"samples":samples,"failures":failures,"scope":"Actual controls renderer source rows/key boxes/headings and responsive layout output at three widths. Not source glyph pixel parity or scrollbar interaction."}
 FileAccess.open("res://evidence/control-content-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));content.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
