extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/title-bars-css.json"));var bars=preload("res://scripts/title_bars.gd").new();root.add_child(bars);bars.show_title(true);bars.show_title(false)
 var failures=[];var maximum=0.0;var previous=0.0
 for row in fixture.rows:
  bars.update_frame((row.ms-previous)/1000);previous=row.ms
  var error=absf(bars.amount-row.amount);maximum=maxf(maximum,error)
  if not is_finite(error) or error>1e-5:failures.append([row.ms,bars.amount,row.amount])
 if bars.visible:failures.append("bars not hidden after transition")
 var report={"samples":fixture.rows.size(),"maximum_error":maximum,"failures":failures,"scope":"Browser sampled original .7s cubic-bezier(.2,.7,.2,1) top-bar transform normalized by CSS height and 101% travel; native visibility at completion. No reversal-shortening, wall-clock scheduling or whole-frame pixel proof."}
 FileAccess.open("res://evidence/title-bars-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));bars.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
