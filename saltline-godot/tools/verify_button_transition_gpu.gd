extends SceneTree
class ButtonProbe extends "res://scripts/title_button.gd":
 var now=0.0
 func _clock()->float:return now
var failures=[]
var samples=[]
func _initialize()->void:call_deferred("run")
func move(point:Vector2)->void:
 var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;Input.parse_input_event(event)
func settle()->void:
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
func run()->void:
 var background=ColorRect.new();background.color=Color("0b0d0f");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/button-transition-css.json"))
 for case in fixture.cases:
  move(Vector2(1000,600));await settle()
  var button=ButtonProbe.new();button.text="DEPLOY" if case.primary else "SETTINGS";button.configure(case.primary);button.position=Vector2(100,100);button.size=Vector2(168,52);root.add_child(button);await settle()
  move(Vector2(180,125));await settle()
  if not button.is_hovered():failures.append("probe hover not delivered")
  for row in case.rows:
   button.now=row.ms/1000.0;await settle()
   var actual=root.get_texture().get_image().get_pixel(104,104);var c=row.colors[0];var expected=Color("0b0d0f").blend(Color(c[0],c[1],c[2],c[3]));var error=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
   samples.append({"primary":case.primary,"ms":row.ms,"error":error})
   if error>1.1/255:failures.append([case.primary,row.ms,error])
  button.queue_free();await process_frame
 var report={"samples":samples,"failures":failures,"scope":"Actual production button shader/draw path with injected clock and real native hover: 14 intermediate fill pixels against browser computed CSS on ink background. One 8-bit level tolerance; no real-time scheduling, border/text/focus pixels or reversal."}
 FileAccess.open("res://evidence/button-transition-gpu.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));background.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
