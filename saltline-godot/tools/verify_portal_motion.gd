extends SceneTree
var failures=[]
func expect(value:bool,label:String)->void:
 if not value:failures.append(label)
func invoke(method:String,args:PackedStringArray=[])->Array:
 var output=[]
 var command=PackedStringArray(["call","--session","--dest","org.freedesktop.portal.Desktop","--object-path","/org/freedesktop/portal/desktop","--method","org.saltline.MotionTest."+method]);command.append_array(args)
 var code=OS.execute("/usr/bin/gdbus",command,output,true)
 expect(code==0,"mock method "+method);return output
func _initialize()->void:call_deferred("run")
func run()->void:
 var expected=int(OS.get_environment("SALTLINE_TEST_MOTION_INITIAL"))
 var initial=DisplayServer.accessibility_should_reduce_animation();expect(initial==expected,"portal initial value")
 for i in 6000:expect(DisplayServer.accessibility_should_reduce_animation()==initial,"cached getter changed")
 var reads_before=invoke("GetReadCount")
 var samples=[]
 for value in [1,0,17,1]:
  invoke("SetMotion",PackedStringArray([str(value)]));await create_timer(.15).timeout
  var current=DisplayServer.accessibility_should_reduce_animation();var target=1 if value==1 else 0
  expect(current==target,"setting notification "+str(value));samples.append({"signal":value,"value":current})
 invoke("WrongType");await create_timer(.15).timeout;expect(DisplayServer.accessibility_should_reduce_animation()==1,"malformed signal changed valid cache")
 invoke("OtherKey");await create_timer(.15).timeout;expect(DisplayServer.accessibility_should_reduce_animation()==1,"unrelated key changed valid cache")
 var reads_after=invoke("GetReadCount");expect(reads_before==reads_after,"getter or signal caused another DBus Read")
 var main_wiring=false
 if expected==0:
  var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
  await process_frame;RenderingServer.force_draw(false)
  var policy=preload("res://scripts/motion_preference.gd")
  expect(policy.reduced,"actual Main startup did not read reduced preference")
  for value in [0,1]:
   invoke("SetMotion",PackedStringArray([str(value)]));await create_timer(.15).timeout;game.game_ui.update_frame(.001)
   expect(policy.reduced==(value==1),"actual GameUI did not follow portal "+str(value))
  expect(reads_before==invoke("GetReadCount"),"Main queried DBus again")
  game._dispose_game();game.queue_free();await process_frame;main_wiring=true
 var report={"failures":failures,"initial":initial,"samples":samples,"cached_getter_calls":6000,"reads_before":reads_before,"reads_after":reads_after,"main_wiring":main_wiring,"scope":"Actual X11 engine API against private DBus portal mock. Initial normal/reduced/unsupported, notifications, unknown uint normalization, malformed/unrelated signal rejection and no per-query/signal DBus reads. Initial0 also checks actual Main startup and GameUI live updates without policy injection. Host desktop settings untouched."}
 FileAccess.open(OS.get_environment("SALTLINE_TEST_MOTION_REPORT"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
