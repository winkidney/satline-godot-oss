extends SceneTree
func color(values:Array)->Color:return Color(values[0],values[1],values[2],values[3])
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/button-transition-css.json"));var failures=[];var checks=0;var maximum=0.0
 for case in fixture.cases:
  var tween=preload("res://scripts/css_color_transition.gd").new();var start=[];var target=[]
  for value in case.start:start.append(color(value))
  for value in case.target:target.append(color(value))
  tween.reset(start,-1);tween.set_target(target,0)
  for row in case.rows:
   var actual=tween.sample(row.ms/1000.0)
   for i in 3:
    for channel in 4:
     checks+=1;var error=absf(actual[i][channel]-row.colors[i][channel]);maximum=maxf(maximum,error)
     if not is_finite(error) or error>.6/255:failures.append([case.primary,row.ms,i,channel,error])
 var report={"checks":checks,"maximum_channel_error":maximum,"failures":failures,"css_sha256":fixture.css_sha256,"scope":"Two original CSS hover transitions, 14 browser time samples, three colors/four channels. Legacy alpha quantization and premultiplied sRGB interpolation/default ease; tolerance covers computed CSS rounding. No reversal-shortening, active interruption or whole-frame pixels."}
 FileAccess.open("res://evidence/button-transition-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
