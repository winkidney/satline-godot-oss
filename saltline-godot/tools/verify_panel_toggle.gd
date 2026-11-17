extends SceneTree
class Probe extends "res://scripts/panel_toggle.gd":
 var now=0.0
 func _clock()->float:return now
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/toggle-css.json"));var probe=Probe.new();probe.configure(false);root.add_child(probe);probe.set_process(false)
 var now=0.0;var failures=[];var checks=0;var maximum_shift=0.0;var maximum_color=0.0
 for stage in reference.stages:
  probe.button_pressed=stage.on;probe.now=now;probe._process(0.0)
  for sample in stage.samples:
   probe.now=now+sample.ms/1000.0;probe._process(0.0)
   var shift=absf(probe.amount*20-sample.shift);maximum_shift=maxf(maximum_shift,shift);checks+=1
   if shift>1e-4:failures.append({"on":stage.on,"ms":sample.ms,"shift":shift})
   for c in 4:
    var error=absf(probe.thumb_color[c]-sample.color[c]);maximum_color=maxf(maximum_color,error);checks+=1
    if error>.004:failures.append({"on":stage.on,"ms":sample.ms,"color":error})
  now+=stage.elapsed/1000.0
 var report={"checks":checks,"maximum_shift_error":maximum_shift,"maximum_color_error":maximum_color,"failures":failures,"scope":"Production toggle process against original Chrome pseudo-element transform/background through four interrupted transitions. Injected clock, not native pointer delivery or font pixels."}
 FileAccess.open("res://evidence/panel-toggle-timing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));probe.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
