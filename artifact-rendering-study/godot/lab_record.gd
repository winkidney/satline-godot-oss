extends Node

var lab:Node
var plan:Dictionary
var started=0
var next_sample=0.0
var previous_frames=0
var index=0
var samples:Array=[]
var camera_origin=Vector3.ZERO

func start(owner:Node,path:String)->void:
 lab=owner;plan=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not plan.has("duration") or not plan.has("report"):push_error("Invalid lab recording plan");queue_free();return
 camera_origin=lab.camera.position
 started=Time.get_ticks_usec();previous_frames=Engine.get_frames_drawn()
 if plan.has("ready"):
  var file=FileAccess.open(str(plan.ready),FileAccess.WRITE)
  if file!=null:file.store_string(JSON.stringify({"started_unix":Time.get_unix_time_from_system()}));file.close()

func _process(_delta:float)->void:
 var elapsed=float(Time.get_ticks_usec()-started)/1000000.0
 var actions:Array=plan.get("actions",[])
 while index<actions.size() and elapsed>=float(actions[index].at):
  var action:Dictionary=actions[index]
  if action.has("lab"):lab.lab=int(action.lab);lab._build();camera_origin=lab.camera.position
  if action.has("filtering"):lab.filtering=bool(action.filtering);lab._apply()
  if action.has("wetness"):lab.wetness=float(action.wetness);lab._apply()
  if action.has("planar"):lab.planar=bool(action.planar);lab._apply()
  if action.has("fog"):lab.fog_enabled=bool(action.fog);lab._apply()
  if action.has("pitch_mm"):lab.pitch_mm=float(action.pitch_mm);lab._apply()
  if action.has("camera"):
   camera_origin=Vector3(1.3,1.3,2.3) if action.camera=="close" else Vector3(2.4,1.8,5.1)
  index+=1
 lab.camera.position=camera_origin+Vector3(sin(elapsed*.3)*.12,0,0)
 lab.camera.look_at(Vector3(0,1.8,-1.4) if lab.lab==3 else Vector3(.8,1.1,0) if lab.lab==0 else Vector3(.8,.9,0))
 if elapsed>=next_sample:
  var count=Engine.get_frames_drawn();samples.append({"seconds":elapsed,"frames":count-previous_frames,"lab":lab.lab});previous_frames=count;next_sample+=1.0
 if elapsed>=float(plan.duration):
  var file=FileAccess.open(str(plan.report),FileAccess.WRITE)
  if file!=null:file.store_string(JSON.stringify({"duration":elapsed,"samples":samples,"actions_executed":index}));file.close()
  print("LAB_REALTIME_RECORDING_REPORT "+str(plan.report));queue_free()
