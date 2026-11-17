extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_ui.settings.sens=1.0;game.game_ui.settings.invertY=false
 game.game_flow.start("mission",false,false,true)
 var failures=[];var samples=[]
 for dimensions in [Vector2i(1280,720),Vector2i(640,360),Vector2i(360,720)]:
  root.size=dimensions
  for i in 12:
   game._process(1.0/60);await process_frame
  if Vector2i(root.get_visible_rect().size)!=dimensions:failures.append("logical viewport differs from window "+str(dimensions))
  var expected=game.render_quality.resolution(dimensions,game.render_quality.PRESETS[game.render_quality.current])
  if game.post_pipeline.world_port.size!=expected:failures.append("world render size "+str(dimensions))
  game.game_flow.state="playing";game.source_touch_input.clear();game.source_touch_input.enabled=false
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;game.source_mouse_input.clear()
  var motion=InputEventMouseMotion.new();motion.device=123;motion.position=Vector2(100,100);motion.relative=Vector2(10,-5)
  root.push_input(motion,false)
  var mouse=game.source_mouse_input.consume()
  if absf(mouse.dx-.021)>.000001 or absf(mouse.dy+.0105)>.000001:failures.append("physical mouse delta scaled "+str(dimensions))
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  var touch=InputEventScreenTouch.new();touch.index=17;touch.position=Vector2(100,300);touch.pressed=true;root.push_input(touch,false)
  var drag=InputEventScreenDrag.new();drag.index=17;drag.position=Vector2(100,271);root.push_input(drag,false)
  var half=game.source_touch_input.move.duplicate()
  if absf(half[1]-.5)>.000001:failures.append("physical half-stick scaled "+str(dimensions))
  drag=InputEventScreenDrag.new();drag.index=17;drag.position=Vector2(100,242);root.push_input(drag,false)
  var full=game.source_touch_input.move.duplicate()
  if absf(full[1]-1)>.000001:failures.append("physical full-stick scaled "+str(dimensions))
  touch=InputEventScreenTouch.new();touch.index=17;touch.position=Vector2(100,242);touch.pressed=false;root.push_input(touch,false)
  samples.append({"window":[dimensions.x,dimensions.y],"logical":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"world":[game.post_pipeline.world_port.size.x,game.post_pipeline.world_port.size.y],"mouse":mouse,"stick_29px":half,"stick_58px":full})
 var report={"failures":failures,"samples":samples,"scope":"Actual Main under production project stretch configuration, no fixture content-scale override. Root.push_input(event,false) supplies physical window mouse/touch coordinates through viewport conversion. Verifies CSS-pixel viewport and render size, identical mouse and 29/58px stick movement in three window shapes. DPR1 only, not all HUD responsive rules or physical hardware acceptance."}
 FileAccess.open("res://evidence/window-coordinates-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
