class_name SaltlineGameFlow
extends RefCounted

signal reset_requested(mode:String,keep_retries:bool)
signal state_changed(state:String)
signal menu_changed(screen:String)
signal capture_mouse(capture:bool)
signal intro_card_changed(visible:bool)
signal radio_requested(text:String,duration:float)
var mission:SaltlineMission
var camera:Camera3D
var state="title"
var menu="title"
var elapsed=0.0
var world_time=0.0
var title_time=0.0
var title_positions:Array=[]
var title_looks:Array=[]
var title_length=1.0
var title_target=Vector3.ZERO
var fade=1.0
var saturation=1.0
var baseline_saturation=1.0
var intro_duration=2.4
var intro_card_shown=false
var intro_radio_sent=false
var location_visible=false
var pause_delay=0.0
var selected_mode="mission"
var holdout_result:Dictionary={}
var best_score=0.0
var storage_path="user://saltline-holdout.json"

func _init(core:SaltlineMission,view:Camera3D,save_path:String="user://saltline-holdout.json")->void:
 mission=core;camera=view;storage_path=save_path;mission.state="title";mission.player.enabled=false
 mission.state_changed.connect(_mission_state)
 for item in mission.level.get("cinematicPath",[]):title_positions.append(_vector(item.pos));title_looks.append(_vector(item.look))
 if title_positions.size()<2:
  var origin=_vector(mission.level.playerStart.pos)
  title_positions=[origin+Vector3(0,2.2,0),origin+Vector3(8,2,0)];title_looks=[origin+Vector3(30,2.5,-2),origin+Vector3(40,3,-2)]
 title_length=0
 for index in range(1,title_positions.size()):title_length+=title_positions[index].distance_to(title_positions[index-1])
 title_length=maxf(title_length,4)
 if not storage_path.is_empty():best_score=_read_best()

func _read_best()->float:
 if not FileAccess.file_exists(storage_path):return 0.0
 var saved=JSON.parse_string(FileAccess.get_file_as_string(storage_path))
 if not saved is Dictionary:return 0.0
 var value=saved.get("best",0)
 if value is String:
  value=value.strip_edges()
  return float(value) if value.is_valid_float() else 0.0
 if value is float or value is int or value is bool:return float(value)
 return 0.0

func _vector(value:Variant)->Vector3:return value if value is Vector3 else Vector3(value[0],value[1],value[2])
func _menu(value:String)->void:
 if menu==value:return
 menu=value;menu_changed.emit(value)
func _set_state(value:String)->void:
 if state==value:return
 state=value;elapsed=0;mission.state=value;state_changed.emit(value)
func _location(visible:bool)->void:location_visible=visible;intro_card_changed.emit(visible)

func start(mode:String="",quick:bool=false,keep_retries:bool=false,skip_intro:bool=false)->void:
 var next_mode=mode if not mode.is_empty() else mission.run.mode if quick or keep_retries else selected_mode
 if not keep_retries:mission.run.retries=0
 _menu("none");_location(false);reset_requested.emit(next_mode,keep_retries)
 holdout_result={};mission.player.enabled=true;fade=0 if skip_intro else 1;saturation=baseline_saturation
 if skip_intro:_playing();return
 intro_duration=mission.flow.retryIntroSeconds if quick else mission.flow.introSeconds;intro_card_shown=quick;intro_radio_sent=quick
 _set_state("intro");capture_mouse.emit(true)

func retry()->void:
 mission.run.retries+=1;start("",true,true)
func redeploy()->void:start("",true,false)
func _playing()->void:
 mission.player.enabled=true;_menu("none");_set_state("playing");capture_mouse.emit(true)

func pause()->void:
 if state=="intro":_location(false);fade=0;_set_state("playing")
 if state!="playing":return
 pause_delay=.35;_menu("paused");_set_state("paused");capture_mouse.emit(false)
func resume()->void:
 if state!="paused":return
 _menu("none");_set_state("playing");capture_mouse.emit(true)

func _mission_state(value:String)->void:
 if value==state:return
 _set_state(value)
 if value in ["dead","complete"]:
  capture_mouse.emit(false)
  if value=="dead" and mission.run.mode=="holdout":_score_holdout()

func _score_holdout()->void:
 # The source reads localStorage at each result, including after another run saves.
 if not storage_path.is_empty():best_score=_read_best()
 var score=int(floor(mission.run.score+.5));var record=score>best_score
 if record:
  best_score=score
  if not storage_path.is_empty():
   var file=FileAccess.open(storage_path,FileAccess.WRITE)
   if file!=null:file.store_string(JSON.stringify({"best":best_score}));file.close()
 holdout_result={"waves":mission.run.wavesCleared,"kills":mission.run.kills,"score":score,"best":best_score,"record":record}

static func sample_path(points:Array,progress:float)->Vector3:
 var last=points.size()-1;var cursor=clampf(progress,0,1)*last;var index=mini(last-1,int(floor(cursor)));var t=cursor-index
 var a:Vector3=points[maxi(0,index-1)];var b:Vector3=points[index];var c:Vector3=points[index+1];var d:Vector3=points[mini(last,index+2)]
 return (b*2+(-a+c)*t+(a*2-b*5+c*4-d)*t*t+(-a+b*3-c*3+d)*t*t*t)*.5

func _title(dt:float)->void:
 var duration=maxf(26,title_length/mission.flow.titleSpeed);title_time+=dt
 if title_time>=duration:title_time=0
 var progress=title_time/duration;var eased=progress*progress*(3-2*progress)*.25+progress*.75
 var position=sample_path(title_positions,eased);var target=sample_path(title_looks,eased)
 position.x+=sin(world_time*.31)*.05;position.y+=sin(world_time*.43+1.7)*.035;position.z+=sin(world_time*.27+.6)*.05
 target.y+=sin(world_time*.19)*.12;target.x+=sin(world_time*.13+2)*.2
 title_target=target
 camera.global_position=position;camera.rotation_order=EULER_ORDER_YXZ;camera.look_at(target,Vector3.UP);camera.rotation.z+=sin(world_time*.21)*.006;camera.fov=mission.flow.titleFov
 fade=maxf(1-smoothstep(0,1.8,title_time),smoothstep(duration-1.6,duration,title_time))

# Returns the original loop's player/weapon/enemy/explosive simulation gate.
func update(dt:float,interact_held:bool=false,pause_pressed:bool=false)->bool:
 world_time+=dt;elapsed+=dt
 match state:
  "title":_title(dt);return false
  "intro":
   fade=1-smoothstep(.05,minf(intro_duration,1.3),elapsed)
   if not intro_card_shown and elapsed>.25:intro_card_shown=true;_location(true)
   if not intro_radio_sent and elapsed>.9:
    intro_radio_sent=true;radio_requested.emit(mission.rules.radio.intro,4.2)
   if pause_pressed:pause();return false
   if elapsed>=intro_duration:_location(false);fade=0;_playing()
   return true
  "playing":
   fade=lerpf(fade,0,1-exp(-6*dt))
   if pause_delay>0:pause_delay-=dt
   if pause_pressed:mission.run.time+=dt;pause();return false
   mission.update(dt,interact_held);return true
  "paused":
   if pause_delay>0:pause_delay-=dt
   elif pause_pressed:resume()
   return false
  "dead":
   saturation=lerpf(saturation,.12,1-exp(-2.2*dt));fade=lerpf(fade,.55,1-exp(-1.4*dt))
   if elapsed>1.5:_menu("dead")
   return true
  "complete":
   fade=lerpf(fade,.72,1-exp(-.9*dt));saturation=lerpf(saturation,baseline_saturation*.7,1-exp(-dt))
   if elapsed>3.3:_menu("complete")
   return true
 return false

func dispose()->void:
 if mission.state_changed.is_connected(_mission_state):mission.state_changed.disconnect(_mission_state)
