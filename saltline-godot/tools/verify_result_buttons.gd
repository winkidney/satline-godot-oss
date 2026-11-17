extends SceneTree
func _initialize()->void:call_deferred("run")
func move(point:Vector2)->void:
 var event=InputEventMouseMotion.new();event.position=point;event.global_position=point;Input.parse_input_event(event)
func settle()->void:
 for i in 20:await process_frame
 RenderingServer.force_draw(false)
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game._process(0.0)
 var ui=game.game_ui;var failures=[];var samples=[]
 game.mission.debrief={"rating":"Clean","time":30.0,"accuracy":.5,"kills":3,"retries":0}
 for screen in ["paused","dead","complete"]:
  move(Vector2(2,2));ui._show(screen);await settle()
  var keys=["resume","settings","controls","restart"] if screen=="paused" else ["retry"] if screen=="dead" else ["redeploy"]
  for key in keys:
   var button=ui.buttons[key]
   if button.get_script()!=preload("res://scripts/title_button.gd"):failures.append(screen+"/"+key+" CSS renderer")
   var normal=button.state_colors();move(button.get_global_rect().get_center());await settle()
   if not button.is_hovered():failures.append(screen+"/"+key+" native hover")
   var colors=button.state_colors();var expected=Color("ffc977") if button.primary else Color(Color("e8e4da"),.12)
   if colors[0]!=expected:failures.append(screen+"/"+key+" hover fill")
   samples.append({"screen":screen,"action":key,"primary":button.primary,"hover_fill":[colors[0].r,colors[0].g,colors[0].b,colors[0].a]})
   move(Vector2(2,2));await settle()
  root.get_texture().get_image().save_png("res://evidence/result-buttons-"+screen+".png")
 var report={"samples":samples,"failures":failures,"scope":"Actual Main pause/death/complete action buttons share original CSS button draw/transition implementation and receive native hover. Existing GPU color fixtures cover renderer; this checks real screen wiring, not whole menu typography/layout parity."}
 FileAccess.open("res://evidence/result-buttons-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
