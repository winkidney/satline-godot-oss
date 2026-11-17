extends Node

var game:Node
var actions:Array=[]
var index=0
var started=0
var next_sample=0.0
var previous_frames=0
var samples:Array=[]
var output=""
var duration=0.0
var intervals:Array[float]=[]
var last_draw_count=0
var last_draw_usec=0
var started_unix=0.0

func start(owner:Node,path:String)->void:
 game=owner
 var plan=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not plan is Dictionary or not plan.has("duration") or not plan.has("report"):
  push_error("Invalid recording plan");queue_free();return
 actions=plan.get("actions",[]);duration=float(plan.duration);output=str(plan.report)
 started=Time.get_ticks_usec();started_unix=Time.get_unix_time_from_system();previous_frames=Engine.get_frames_drawn();last_draw_count=previous_frames;last_draw_usec=started
 if plan.has("ready"):
  var file=FileAccess.open(str(plan.ready),FileAccess.WRITE)
  if file!=null:file.store_string(JSON.stringify({"started_unix":started_unix}));file.close()

func _process(_delta:float)->void:
 var now=Time.get_ticks_usec();var elapsed=float(now-started)/1000000.0
 var drawn=Engine.get_frames_drawn()
 if drawn>last_draw_count:
  intervals.append(float(now-last_draw_usec)/1000.0);last_draw_count=drawn;last_draw_usec=now
 while index<actions.size() and elapsed>=float(actions[index].at):
  _action(actions[index]);index+=1
 if elapsed>=next_sample:
  var frames=Engine.get_frames_drawn();samples.append({"seconds":elapsed,"frames":frames-previous_frames,"state":game.game_flow.state})
  previous_frames=frames;next_sample+=1.0
 if elapsed>=duration:
  var file=FileAccess.open(output,FileAccess.WRITE)
  if file==null:push_error("Cannot write recording report")
  else:file.store_string(JSON.stringify({"duration":elapsed,"started_unix":started_unix,"samples":samples,"frame_intervals_ms":intervals,"actions_executed":index}));file.close()
  print("REALTIME_RECORDING_REPORT "+output);queue_free()

func _action(action:Dictionary)->void:
 var kind=str(action.kind)
 if kind=="key":
  var event=InputEventKey.new();event.keycode=OS.find_keycode_from_string(str(action.key));event.physical_keycode=event.keycode;event.pressed=bool(action.get("down",true));event.device=0;Input.parse_input_event(event)
 elif kind=="fire":
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=bool(action.get("down",true));event.device=0;Input.parse_input_event(event)
 elif kind=="warp":
  var position=action.pos;game.player.pos=Vector3(position[0],position[1],position[2]);game.player.safe_pos=game.player.pos;game.player.velocity=Vector3.ZERO
  game.player.yaw=float(action.yaw);game.player.pitch=float(action.get("pitch",0))
 elif kind=="invulnerable":game.player.invulnerable=bool(action.get("enabled",true))
