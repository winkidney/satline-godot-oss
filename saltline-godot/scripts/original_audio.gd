extends Node

const ROOT="res://assets/audio/original/"
const MUSIC=["music_drone","music_strings","music_pulse","music_ticks","music_drums","music_brass","music_lift"]
const BUS_GAIN={"world":1.25,"near":1.24,"gun":1.0,"tail":1.0,"amb":0.767,"dry":1.3,"music":0.73}
const WET={"world":0.18,"near":0.09,"gun":0.025,"tail":0.0,"amb":0.04,"dry":0.0,"music":0.07}
const RELOAD={"rifle":{"magout":"reload_magout","maginsert":"reload_maginsert","magin":"reload_magin","boltback":"reload_boltback","bolt":"reload_bolt","slide":"reload_bolt"},"pistol":{"magout":"pistol_magout","maginsert":"pistol_maginsert","magin":"pistol_magin","boltback":"pistol_slide","bolt":"pistol_slide","slide":"pistol_slide"}}
const IMPACT={"metal":"impact_metal","concrete":"impact_concrete","wood":"impact_wood","water":"impact_water","glass":"impact_glass","dirt":"impact_concrete","rubber":"impact_wood","enemy":"impact_enemy"}
const STEP={"metal":"step_metal","water":"step_water","concrete":"step_concrete","wood":"step_concrete","dirt":"step_concrete"}

var game
var catalog:Dictionary={}
var streams:Dictionary={}
var variant_history:Dictionary={}
var voices:Dictionary={}
var random=RandomNumberGenerator.new()
var score:AudioStreamSynchronized
var score_player:AudioStreamPlayer
var ambience:Dictionary={}
var reverb:Dictionary={}
var state="title"
var live_state="title"
var interior=0.0
var intensity=0.0
var auto_intensity=0.0
var score_time=0.0
var score_started_usec=0
var next_bar=0
var music_plan="rest"
var music_cycle=0
var music_quiet=0
var last_fill=-1
var music_final=false
var enemy_loops:Dictionary={}
var relay_loops:Dictionary={}
var ambient_timers:Dictionary={}
var duck=1.0
var duck_hold=0.0
var last_shell=-10.0
var last_impact=-10.0
var last_alert=-10.0
var last_ring=-10.0
var event_log:Array[Dictionary]=[]

func _exit_tree()->void:
 for child in get_children():
  if child is AudioStreamPlayer or child is AudioStreamPlayer3D:child.stop();child.stream=null
 streams.clear();score=null

func setup(owner:Node)->void:
 game=owner;process_mode=Node.PROCESS_MODE_ALWAYS;random.randomize()
 var manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
 if not manifest is Dictionary or not manifest.has("sounds"):
  push_error("Original audio manifest is missing or invalid");set_process(false);return
 catalog=manifest.sounds
 _setup_buses();set_master_volume(float(game.game_ui.settings.volume));_connect_game();_start_score();_start_ambience()

func _setup_buses()->void:
 var present=[]
 for i in AudioServer.get_bus_effect_count(0):present.append(AudioServer.get_bus_effect(0,i).resource_name)
 if not "SaltlineCompressor" in present:
  var compressor=AudioEffectCompressor.new();compressor.resource_name="SaltlineCompressor";compressor.threshold=-3;compressor.ratio=2;compressor.attack_us=10000;compressor.release_ms=120;AudioServer.add_bus_effect(0,compressor)
 if not "SaltlineLimiter" in present:
  var limiter=AudioEffectLimiter.new();limiter.resource_name="SaltlineLimiter";limiter.ceiling_db=-.1;AudioServer.add_bus_effect(0,limiter)
 for name in BUS_GAIN:
  var bus_name="Saltline"+str(name).capitalize();var index=AudioServer.get_bus_index(bus_name)
  if index<0:AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus_name)
  AudioServer.set_bus_send(index,"Master");AudioServer.set_bus_volume_db(index,linear_to_db(float(BUS_GAIN[name])))
  if float(WET[name])>0 and AudioServer.get_bus_effect_count(index)==0:
   # shortcut: algorithmic reverb approximates the source impulses; use convolution if matched tails are required.
   var effect=AudioEffectReverb.new();effect.dry=1.0;effect.wet=float(WET[name]);effect.room_size=.55;effect.damping=.5
   AudioServer.add_bus_effect(index,effect);reverb[name]=effect

func set_master_volume(value:float)->void:
 var volume=clampf(value,0,1) if is_finite(value) else .8
 AudioServer.set_bus_mute(0,volume<=0);AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,.0001)))

func _connect_game()->void:
 game.weapon.fired.connect(_weapon_fired);game.weapon.phase_event.connect(_weapon_phase)
 game.player.motion_event.connect(_player_motion);game.player.hit.connect(_player_hit);game.player.died.connect(_player_died)
 game.combat.impact.connect(_impact);game.enemy_manager.bolts.impact.connect(_impact)
 game.shells.bounced.connect(_shell_bounce)
 game.explosion_effects.exploded.connect(_explosion);game.mission.objective_done.connect(_objective_done);game.mission.objective_all.connect(_objective_all)
 game.game_flow.state_changed.connect(_state_changed);game.game_ui.setting_changed.connect(_setting_changed);game.game_ui.ui_sound.connect(_ui_sound)
 game.enemy_manager.spawned.connect(_enemy_spawned)
 game.enemy_coordinator.alerted.connect(_enemy_alert)
 game.mission.relay_changed.connect(_relay_changed)
 for relay in game.mission.relays:_relay_changed(relay,"live")
 for actor in game.enemy_manager.pools.hound:
  actor.shot.connect(_hound_shot);actor.killed.connect(_hound_killed);actor.melee.connect(_hound_melee);actor.behavior.telegraph.connect(_hound_telegraph.bind(actor));actor.pose.footstep.connect(_hound_step)
 for actor in game.enemy_manager.pools.gull:
  actor.bolt_requested.connect(_gull_shot);actor.killed.connect(_gull_killed);actor.behavior.telegraph.connect(_gull_telegraph.bind(actor))
 for actor in game.enemy_manager.active:_enemy_spawned(actor)

func attach_weather(weather:Variant)->void:weather.thunder.connect(_thunder)

func _stream(name:String,variant:int=0)->AudioStreamWAV:
 if not catalog.has(name):return null
 var entries:Array=catalog[name].variants
 if entries.is_empty():return null
 variant=posmod(variant,entries.size());var key="%s-%d"%[name,variant]
 if streams.has(key):return streams[key]
 var info:Dictionary=entries[variant];var file=FileAccess.open(ROOT+key+".wav",FileAccess.READ)
 if file==null:push_error("Missing original sound: "+key);return null
 var expected=int(info.frames)*int(info.channels)*2
 if file.get_length()!=44+expected:push_error("Invalid original sound length: "+key);return null
 file.seek(44);var result=AudioStreamWAV.new();result.format=AudioStreamWAV.FORMAT_16_BITS;result.stereo=int(info.channels)==2;result.mix_rate=int(info.sample_rate);result.data=file.get_buffer(expected)
 if bool(info.loop):result.loop_mode=AudioStreamWAV.LOOP_FORWARD;result.loop_begin=0;result.loop_end=int(info.frames)
 streams[key]=result;return result

func play_sound(name:String,position:Variant=null,gain:float=1.0,pitch:float=1.0,variant:int=-1,jitter:float=.035,ref_override:float=-1.0)->void:
 if not catalog.has(name):return
 var info:Dictionary=catalog[name];var properties:Dictionary=info.properties
 if bool(properties.get("ir",false)) or bool(properties.get("loop",false)):return
 var count=info.variants.size()
 if variant<0:
  variant=(int(variant_history.get(name,0))+1+(1 if count>2 and random.randf()<.3 else 0))%count;variant_history[name]=variant
 var sound=_stream(name,variant)
 if sound==null:return
 var active:Array=voices.get(name,[]);active=active.filter(func(item):return is_instance_valid(item) and item.playing)
 var limit=int(properties.get("max",6))
 if active.size()>=limit:active.pop_front().queue_free()
 var bus=str(properties.get("bus","world"));var node
 if position is Vector3 and bus=="world":
  node=AudioStreamPlayer3D.new();add_child(node);node.global_position=position;node.unit_size=ref_override if ref_override>0 else float(properties.get("ref",3));node.max_distance=maxf(120.0,ref_override*4)
 else:
  node=AudioStreamPlayer.new();add_child(node)
 node.bus="Saltline"+bus.capitalize();node.stream=sound;node.pitch_scale=clampf(pitch*(1+random.randf_range(-jitter,jitter)),.25,4)
 node.volume_db=linear_to_db(maxf(.0001,gain*(1-random.randf()*.08)));node.finished.connect(node.queue_free);active.append(node);voices[name]=active;node.play()
 event_log.append({"name":name,"variant":variant,"gain":gain,"pitch":pitch,"position":position})
 if event_log.size()>256:event_log.pop_front()

func _start_score()->void:
 score=AudioStreamSynchronized.new();score.stream_count=MUSIC.size()
 for i in MUSIC.size():
  score.set_sync_stream(i,_stream(MUSIC[i]));score.set_sync_stream_volume(i,-80)
 score_player=AudioStreamPlayer.new();score_player.bus="SaltlineMusic";score_player.stream=score;add_child(score_player);score_started_usec=Time.get_ticks_usec();score_player.play()

func _start_ambience()->void:
 for name in ["rain","rain_interior","wind","sea"]:
  var node=AudioStreamPlayer.new();node.bus="SaltlineAmb";node.stream=_stream(name);node.volume_db=-80;add_child(node);node.play();ambience[name]=node
 ambient_timers={"foghorn":random.randf_range(14,28),"gull_cry":random.randf_range(5,13),"halyard":random.randf_range(4,10),"container_bang":random.randf_range(20,45)}

func _process(dt:float)->void:
 if game==null or score==null:return
 var delta=minf(dt,.1);score_time=float(Time.get_ticks_usec()-score_started_usec)/1000000.0;duck_hold=maxf(0,duck_hold-delta)
 duck=lerpf(duck,1.0 if duck_hold<=0 else duck,1-exp(-delta/.1))
 var room=1.0 if game.source_ibl_service!=null and game.source_ibl_service.view_room else 0.0
 interior=lerpf(interior,room,1-exp(-delta*2))
 auto_intensity=maxf(0,auto_intensity-delta*.035)
 var desired=float(game.mission.run.get("intensity",.15)) if game.mission!=null else .15
 intensity=lerpf(intensity,maxf(desired,auto_intensity),1-exp(-delta*2))
 var medium=smoothstep(.3,.6,intensity);var high=smoothstep(.7,.95,intensity)
 var final_high=high if music_final else 0.0
 var levels=[1-.15*medium-.15*high-.2*final_high,medium*(.85+.15*high),medium*(.8+.2*high)*(1-.2*final_high),medium*(.7+.3*high),high,high*(1-.15*final_high),final_high]
 if live_state in ["title","intro"]:levels=[.95,0,0,0,0,0,0]
 elif live_state=="dead":levels=[.4,0,0,0,0,0,0]
 elif live_state=="complete":levels=[.7,0,0,0,0,0,0]
 for i in MUSIC.size():score.set_sync_stream_volume(i,linear_to_db(maxf(.0001,float(levels[i])*.92)))
 AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SaltlineMusic"),linear_to_db(.73*maxf(.0001,duck*(.45 if state=="paused" else 1.0))))
 var ambient_gain=.0 if state=="paused" else 1.0
 _ambient("rain",.3*(1-interior)*ambient_gain*duck);_ambient("rain_interior",.18*interior*ambient_gain*duck)
 _ambient("wind",.22*(1-interior*.6)*ambient_gain*duck);_ambient("sea",.13*(1-interior)*ambient_gain*duck)
 for effect in reverb.values():effect.room_size=lerpf(.55,.82,interior)
 _update_enemy_loops()
 for node in relay_loops.values():node.volume_db=-80.0 if state=="paused" else linear_to_db(.9)
 if state!="paused":_ambient_events(delta)
 _music_bar()

func _ambient(name:String,gain:float)->void:
 if ambience.has(name):ambience[name].volume_db=linear_to_db(maxf(.0001,gain))

func _ambient_events(delta:float)->void:
 var listener:Vector3=game.camera.global_position;var attenuation=1-.7*interior
 for name in ambient_timers:
  ambient_timers[name]=float(ambient_timers[name])-delta
  if ambient_timers[name]>0:continue
  var pos:Vector3;var gain=1.0;var ref=16.0;var pitch=1.0
  match name:
   "foghorn":
    ambient_timers[name]=random.randf_range(40,70);pos=listener+Vector3(320,8,random.randf_range(-250,250));ref=400;gain=.34*attenuation;pitch=.89 if random.randf()<.3 else 1.0
   "gull_cry":
    ambient_timers[name]=random.randf_range(9,25);var angle=random.randf_range(0,TAU);ref=random.randf_range(35,85);pos=listener+Vector3(cos(angle)*ref,random.randf_range(14,32),sin(angle)*ref);gain=random.randf_range(.16,.32)*attenuation
   "halyard":
    ambient_timers[name]=random.randf_range(6,17);pos=Vector3(random.randf_range(29,37),random.randf_range(3,9),random.randf_range(-8,24));gain=random.randf_range(.3,.6)*attenuation
   _:
    ambient_timers[name]=random.randf_range(28,62);var angle=random.randf_range(1.6,4.8);pos=listener+Vector3(cos(angle)*150,4,sin(angle)*150);ref=150;gain=random.randf_range(.2,.36)*attenuation
  play_sound(name,pos,gain,pitch,-1,.08,ref)

func _relay_changed(relay:Dictionary,visual_state:String)->void:
 var id=str(relay.id)
 if visual_state=="cut":
  if relay_loops.has(id):relay_loops[id].stop();relay_loops[id].queue_free();relay_loops.erase(id)
  return
 if relay_loops.has(id):return
 var node=AudioStreamPlayer3D.new();node.bus="SaltlineWorld";node.stream=_stream("relay_hum");node.unit_size=2.5;node.max_distance=120;add_child(node)
 node.global_position=relay.o.pos+Vector3(0,1.2,0);node.volume_db=linear_to_db(.9);node.play();relay_loops[id]=node

func _music_bar()->void:
 if score_time<next_bar*2.5:return
 var bar=int(floor(score_time/2.5));next_bar=bar+1;var phase=bar%8
 if live_state=="dead":return
 if live_state=="complete":
  if phase==0 and random.randf()<.6:play_sound("mus_cell",null,.64,1,0,0)
  return
 var tier=2 if intensity>=.8 and live_state=="playing" else 1 if intensity>=.4 and live_state=="playing" else 0
 if phase==0:
  var pick=random.randf();music_cycle+=1
  if live_state in ["title","intro"]:music_plan="full" if music_plan!="full" else "rest"
  elif tier==0:
   if music_quiet>=1:music_plan="call" if pick<.5 else "full call" if pick<.8 else "answer"
   else:music_plan="call" if pick<.3 else "full call" if pick<.48 else "tail" if pick<.62 else "answer" if pick<.72 else "rest"
  elif tier==1:music_plan="call" if pick<.4 else "tail" if pick<.55 else "rest"
  elif music_final:music_plan="full" if music_cycle%2==1 else "call"
  else:music_plan=["rest","full call","rest","full"][music_cycle%4]
  music_quiet=music_quiet+1 if music_plan=="rest" else 0
 var part=phase>>1
 var melodic=phase%2==0 and (music_plan=="full" or (music_plan=="call" and part==0) or (music_plan=="full call" and part<2) or (music_plan=="tail" and part==3) or (music_plan=="answer" and part>=2))
 if tier==2:
  if melodic:play_sound("mus_horn",null,.7,1,part,0)
  if (phase==3 and random.randf()<(.6 if music_final else .3)) or (phase==7 and random.randf()<(1.0 if music_final else .8)):
   var fill=random.randi_range(0,2)
   if fill==last_fill:fill=(fill+1)%3
   last_fill=fill;play_sound("mus_fill",null,.55,1,fill,0)
 elif melodic:play_sound("mus_cell",null,.68 if tier==1 else .8,1,part,0)
 elif live_state in ["title","intro"] and phase==5 and random.randf()<.5:play_sound("mus_hit",null,.336,1,0,0)
 elif live_state=="playing" and tier==0 and phase in [1,4] and random.randf()<(.5 if phase==4 else .2):play_sound("mus_hit",null,.42*(.7+.3*random.randf()),1,random.randi_range(0,1),0)
 elif live_state=="playing" and tier==1 and (phase==0 or (phase==4 and random.randf()<.4)):play_sound("mus_hit",null,.357,1,0 if phase==0 else 1,0)

func _weapon_fired(id:String,_definition:Dictionary,_spread:float)->void:
 play_sound(id+"_shot",null,1.12,1,-1,.012)
 var out_gain=cos(interior*PI*.5);var in_gain=sin(interior*PI*.5)
 if out_gain>.05:play_sound(id+"_tail_out",null,1.12*out_gain,1,-1,.02)
 if in_gain>.05:play_sound(id+"_tail_in",null,1.12*in_gain,1,-1,.02)
 duck=.5 if id=="pistol" else .45;duck_hold=.085;auto_intensity=maxf(auto_intensity,.6)

func _weapon_phase(event:String,id:String,phase:String)->void:
 if event=="dry":play_sound(id+"_dry",null,1,1,-1,.02)
 elif event=="switch":play_sound("weapon_"+phase,null,.8 if id=="pistol" else 1.0,1.15 if id=="pistol" else 1.0)
 elif event=="reload":
  if phase in ["start","done"]:play_sound("gear_rustle",null,.9 if phase=="start" else .6,1.12 if id=="pistol" else 1.0,0 if phase=="start" else 1)
  elif RELOAD.has(id) and RELOAD[id].has(phase):
   var partial=phase=="boltback" and id=="rifle" and not bool(game.weapon.reload.get("empty",false))
   play_sound(RELOAD[id][phase],null,.6 if partial else 1.0,1.0,1 if partial else 0,.02)

func _player_motion(kind:String,payload:Dictionary)->void:
 var surface=str(payload.get("surface","concrete"))
 if kind=="step":play_sound(STEP.get(surface,"step_concrete"),null,.8 if payload.get("sprint",false) else .55)
 elif kind=="jump":play_sound("jump",null,.8)
 elif kind=="land":
  var gain=clampf(.35+absf(float(payload.get("speed",4)))/10,.35,1);play_sound("land",null,gain)
  if surface in ["water","metal"]:play_sound(STEP[surface],null,gain*.8,.9)

func _player_hit(amount:float,_from:Variant)->void:
 play_sound("hurt",null,clampf(.5+amount/40,.5,1),1,-1,.08);auto_intensity=maxf(auto_intensity,.6)
 var now=Time.get_ticks_msec()/1000.0
 if amount>=6 and now-last_ring>1.8:last_ring=now;play_sound("ear_ring",null,clampf(amount/28,.3,1),1,-1,.02)
func _player_died()->void:play_sound("death",null,.9)
func _impact(hit:Dictionary)->void:
 var now=Time.get_ticks_msec()/1000.0
 if now-last_impact<.022:return
 last_impact=now;var surface=str(hit.get("surface","concrete"));play_sound(IMPACT.get(surface,"impact_concrete"),hit.get("point"),.8 if hit.get("from")=="enemy" else .9)
func _shell_bounce(position:Vector3,surface:String,_bounce:int)->void:
 var now=Time.get_ticks_msec()/1000.0
 if now-last_shell<.04:return
 last_shell=now
 if surface=="water":play_sound("impact_water",position,.25,1.7)
 else:play_sound("shell_bounce_metal" if surface in ["metal","glass"] else "shell_bounce",position,1.0 if surface in ["metal","glass"] else .85,1.22 if game.weapon.current=="pistol" else 1.0,-1,.06)
func _thunder(amount:float)->void:play_sound("thunder",null,.35+.65*amount,1,1 if amount>.6 else 0,.1)
func _explosion(position:Vector3,size:float)->void:
 play_sound("explosion_big" if size>=1.3 else "explosion",position,clampf(.42+.4*size,.5,1.2));duck=.4;duck_hold=.4;auto_intensity=maxf(auto_intensity,.6)
func _objective_done(_id:String,_index:int,_total:int)->void:play_sound("relay_cut");play_sound("objective",null,.9)
func _objective_all()->void:music_final=true;play_sound("mus_riser",null,.9)
func _state_changed(value:String)->void:
 state=value
 if value!="paused":live_state=value
 if value in ["title","intro"]:music_final=false
 if value=="complete":play_sound("complete",null,.9)
func _setting_changed(key:String,value:Variant)->void:
 if key=="volume":set_master_volume(float(value))
func _ui_sound(kind:String)->void:play_sound("ui_"+kind)
func _enemy_alert(enemy:Dictionary)->void:
 var now=Time.get_ticks_msec()/1000.0
 if now-last_alert<.12:return
 last_alert=now;play_sound("alert",enemy.get("pos"),.9,1,1 if enemy.get("type")=="hound" else 0);auto_intensity=maxf(auto_intensity,.6)
func _hound_shot(position:Vector3,_direction:Vector3,_damage:float)->void:play_sound("hound_fire",position,1,1,-1,.04);auto_intensity=maxf(auto_intensity,.6)
func _hound_step(position:Vector3,speed:float)->void:play_sound("hound_step",position,clampf(.6+speed*.1,.6,1),1,-1,.06)
func _gull_shot(position:Vector3,_direction:Vector3)->void:play_sound("gull_fire",position,1,1,-1,.04);auto_intensity=maxf(auto_intensity,.6)
func _hound_killed(actor:Variant)->void:play_sound("hound_die",actor.state.pos)
func _gull_killed(actor:Variant)->void:play_sound("gull_die",actor.state.pos)
func _hound_melee(_damage:float,position:Vector3)->void:play_sound("hound_step",position,1,.8);play_sound("impact_metal",position,.9,.7)
func _hound_telegraph(duration:float,melee:bool,actor:Variant)->void:play_sound("telegraph",actor.state.pos,.7 if melee else 1,.55/maxf(.15,duration),1,0)
func _gull_telegraph(duration:float,actor:Variant)->void:play_sound("telegraph",actor.state.pos,1,.55/maxf(.15,duration),0,0)

func _enemy_spawned(actor:Variant)->void:
 var key=actor.get_instance_id()
 if enemy_loops.has(key):return
 var kind="hound_servo" if actor is SaltlineHoundActor else "gull_rotor"
 var node=AudioStreamPlayer3D.new();node.bus="SaltlineWorld";node.stream=_stream(kind);node.unit_size=5;node.max_distance=100;add_child(node);node.global_position=actor.state.pos;node.play()
 enemy_loops[key]={"actor":actor,"node":node,"kind":kind}

func _update_enemy_loops()->void:
 for key in enemy_loops.keys():
  var entry:Dictionary=enemy_loops[key];var actor=entry.actor;var node=entry.node
  if not is_instance_valid(actor) or not actor.state.active or not actor.state.alive:
   if is_instance_valid(node):node.stop();node.queue_free()
   enemy_loops.erase(key);continue
  node.global_position=actor.state.pos
  var gain=.0 if state=="paused" else .35 if entry.kind=="gull_rotor" else clampf(.12+float(actor.state.speed)*.08,.12,.4)
  node.volume_db=linear_to_db(maxf(.0001,gain))
