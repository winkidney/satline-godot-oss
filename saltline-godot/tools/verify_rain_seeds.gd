extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 if RenderingServer.get_rendering_device()==null:
  printerr("This instance-buffer verification requires Forward+ GPU; dummy headless backend does not retain readable MultiMesh data.");quit(2);return
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();var rain=SaltlineRain.new(scene)
 var report=rain.verify_exported_seeds();report.failures=[]
 if report.float_components!=40640 or report.maximum_error!=0:report.failures.append("Seed transfer mismatch")
 report.rain_instances=rain.rain.multimesh.instance_count;report.splash_instances=rain.splash.multimesh.instance_count
 report.scope="Original exported aSeed float32 components vs regenerated native MultiMesh INSTANCE_CUSTOM storage, including negative eave seeds. Actual source-quality constructor and shared RNG initialization; GPU negative branch verified separately." 
 var file=FileAccess.open("res://evidence/rain-seed-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if report.failures.is_empty() else 1)
