extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/transition-reversal-css.json"))
 var failures=[];var checks=0;var maximum=0.0
 for case in data.cases:
  var colors=[]
  for c in case.start:colors.append(Color(c[0],c[1],c[2],c[3]))
  var transition=preload("res://scripts/css_color_transition.gd").new();transition.reset(colors,0.0);var now=0.0
  for stage in case.stages:
   var targets=[]
   for c in stage.target:targets.append(Color(c[0],c[1],c[2],c[3]))
   transition.set_target(targets,now)
   for sample in stage.samples:
    var actual=transition.sample(now+sample.ms/1000.0)
    for i in actual.size():
     for c in 4:
      var error=absf(actual[i][c]-sample.colors[i][c]);maximum=maxf(maximum,error);checks+=1
      if error>.004:
       if failures.size()<20:failures.append({"primary":case.primary,"state":stage.state,"ms":sample.ms,"index":i,"component":c,"actual":actual[i][c],"expected":sample.colors[i][c]})
   now+=stage.elapsed/1000.0
 var bars=preload("res://scripts/title_bars.gd").new();root.add_child(bars);bars.show_title(true)
 var bar_maximum=0.0;var bar_checks=0
 for stage in data.bars.stages:
  bars.show_title(stage.on)
  if absf(bars.timing.active_duration-stage.duration/1000.0)>1e-5:failures.append("bar reversal duration")
  var previous=0.0
  for sample in stage.samples:
   bars.update_frame((sample.ms-previous)/1000.0);previous=sample.ms
   var error=absf(bars.amount-sample.amount);bar_maximum=maxf(bar_maximum,error);bar_checks+=1
   if error>1e-5:failures.append({"bar_state":stage.on,"ms":sample.ms,"actual":bars.amount,"expected":sample.amount})
 bars.queue_free()
 var report={"checks":checks,"bar_checks":bar_checks,"bar_maximum_error":bar_maximum,"maximum_error":maximum,"failures":failures,"scope":data.scope}
 FileAccess.open("res://evidence/transition-reversal-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
