extends SceneTree
class ButtonProbe extends "res://scripts/title_button.gd":
 var now=0.0
 var forced=[]
 func _clock()->float:return now
 func state_colors()->Array:return forced if not forced.is_empty() else super.state_colors()
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
func colors(values:Array)->Array:
 var result=[]
 for c in values:result.append(Color(c[0],c[1],c[2],c[3]))
 return result
func run()->void:
 var background=ColorRect.new();background.color=Color("0b0d0f");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/transition-reversal-css.json"));var failures=[];var samples=[];var maximum=0.0
 for case in data.cases:
  var button=ButtonProbe.new();button.forced=colors(case.start);button.text="DEPLOY" if case.primary else "SETTINGS";button.configure(case.primary);button.position=Vector2(100,100);button.size=Vector2(168,52);root.add_child(button);await settle()
  var now=0.0
  for stage in case.stages:
   button.forced=colors(stage.target);button.now=now;await settle()
   for sample in stage.samples:
    button.now=now+sample.ms/1000.0;await settle()
    var actual=root.get_texture().get_image().get_pixel(104,104);var c=sample.colors[0];var expected=background.color.blend(Color(c[0],c[1],c[2],c[3]));var error=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)));maximum=maxf(maximum,error)
    samples.append({"primary":case.primary,"state":stage.state,"ms":sample.ms,"error":error})
    if error>1.1/255:failures.append(samples[-1])
   now+=stage.elapsed/1000.0
  button.queue_free();await process_frame
 var report={"samples":samples,"maximum_error":maximum,"failures":failures,"scope":"Actual production title_button process/color transition/draw path with injected clock and forced CSS-equivalent target states.36 fill pixels versus Chrome reversal/active interruption fixture on ink. Not physical pointer timing or border/text pixel proof."}
 FileAccess.open("res://evidence/button-reversal-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));background.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
