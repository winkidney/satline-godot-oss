extends SceneTree
var failures=[]
var samples=[]
var controls=[]
func _initialize()->void:call_deferred("run")
func settle()->void:
 await create_timer(.15).timeout
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
func move(point:Vector2)->void:
 var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;Input.parse_input_event(event)
func sample(button,label:String,expected:Color)->void:
 var at=button.position+Vector2(4,4);var actual=root.get_texture().get_image().get_pixel(int(at.x),int(at.y))
 var error=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
 samples.append({"label":label,"actual":[actual.r,actual.g,actual.b],"expected":[expected.r,expected.g,expected.b],"error":error})
 if error>1.1/255:failures.append(label)
func run()->void:
 var background=ColorRect.new();background.color=Color("0b0d0f");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
 for i in 3:
  var button=preload("res://scripts/title_button.gd").new();button.text=["SETTINGS","DEPLOY","MISSION"][i];button.configure(i==1);button.position=Vector2(50+i*250,100);button.size=Vector2(168,52);root.add_child(button);controls.append(button)
 controls[2].configure_segmented()
 move(Vector2(1000,600));await settle();sample(controls[0],"normal fill",Color("0b0d0f"));sample(controls[1],"primary fill",Color("ffb347"))
 move(controls[0].position+Vector2(80,25));await settle();sample(controls[0],"hover fill",Color("0b0d0f").blend(Color(Color("e8e4da"),.12)))
 move(controls[1].position+Vector2(80,25));await settle();sample(controls[1],"primary hover",Color("ffc977"))
 controls[2].set_selected(true);await settle();sample(controls[2],"selected fill",Color("e8e4da"))
 var report={"samples":samples,"failures":failures,"scope":"Actual isolated GPU title buttons on known ink background, injected native mouse hover and selected state; five fill-color pixels within one 8-bit level. Source colors from CSS, no font/transition/focus pixel parity."}
 FileAccess.open("res://evidence/title-button-pixels.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));for button in controls:button.queue_free()
 background.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
