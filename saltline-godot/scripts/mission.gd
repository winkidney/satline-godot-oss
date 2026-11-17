class_name SaltlineMission
extends RefCounted

signal radio_requested(text:String,duration:float)
signal hud_reset
signal radio_cleared
signal state_changed(state:String)
signal relay_changed(relay:Dictionary,visual_state:String)
signal progress(id:String,value:float)
signal objective_done(id:String,index:int,total:int)
signal objective_all
signal prompt_changed(text:Variant,value:float)
signal message(text:String,duration:float)
signal warning(text:String,duration:float)
signal objective_changed(text:String)
signal wave_started(wave:int,count:int)
signal resupply(amount:int,reserve_cap:int,reset_explosives:bool)
var rules:Dictionary
var flow:Dictionary={}
var difficulty="hard"
var state="title"
var level:Dictionary
var manager:SaltlineEnemyManager
var player:Variant
var navigation:SaltlineNavigation
var rng:SaltlineSourceRng
var run:Dictionary
var relays:Array=[]
var extraction:Dictionary={}
var spawn_points:Array=[]
var debrief:Dictionary={}
const DIRECTIONS=["NORTH","NORTH-EAST","EAST","SOUTH-EAST","SOUTH","SOUTH-WEST","WEST","NORTH-WEST"]

func _init(scene_level:Dictionary,enemies:SaltlineEnemyManager,avatar:Variant,nav:SaltlineNavigation,random_stream:SaltlineSourceRng=null)->void:
 level=scene_level;manager=enemies;player=avatar;navigation=nav;rng=random_stream if random_stream!=null else preload("res://scripts/source_bootstrap.gd").new().root
 rules=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-rules.json"))
 for record in level.enemySpawns:
  var point:Dictionary=record.duplicate(true);point.pos=_vector(point.pos);spawn_points.append(point)
 extraction=level.extraction.duplicate(true);extraction.pos=_vector(extraction.pos)
 player.died.connect(_on_player_dead);player.hit.connect(_on_player_hit)
 manager.coordinator.alerted.connect(_on_alert);manager.noise_alerted.connect(_on_noise_alert)
 for kind in manager.pools:
  for actor in manager.pools[kind]:actor.killed.connect(_on_killed)
 set_difficulty("hard");_new_run("mission",0)

func _vector(value:Variant)->Vector3:return value if value is Vector3 else Vector3(value[0],value[1],value[2])

func _copy_scalars(target:Dictionary,base:Dictionary,overrides:Dictionary)->void:
 for key in base:
  if not base[key] is Dictionary:target[key]=base[key].duplicate(true) if base[key] is Array else base[key]
 for key in overrides:target[key]=overrides[key].duplicate(true) if overrides[key] is Array or overrides[key] is Dictionary else overrides[key]

func set_difficulty(key:String)->void:
 difficulty=key if rules.difficulty.has(key) else "hard"
 var settings:Dictionary=rules.difficulty[difficulty];var tuning:Dictionary=manager.coordinator.tuning
 _copy_scalars(tuning,rules.enemies,settings.get("ai",{}))
 _copy_scalars(tuning.gull,rules.enemies.gull,settings.get("gull",{}));_copy_scalars(tuning.hound,rules.enemies.hound,settings.get("hound",{}))
 _copy_scalars(player.tuning,rules.player,settings.get("player",{}))
 flow.clear();flow.merge(rules.flow.duplicate(true));flow.merge(settings.get("flow",{}).duplicate(true),true)

func _new_run(mode:String,retries:int)->void:
 var intensity=run.get("intensity",.15)
 run={"mode":mode,"time":0.0,"retries":retries,"cut":0,"allCut":false,"contactSaid":false,"lowSaid":false,"queue":[],"waveHot":0.0,"alertT":0.0,"pursuitT":0.0,"pursuitLeft":0,"extractHint":0.0,"intensity":intensity,"used":{},"wave":0,"waveOn":false,"breakT":rules.holdout.firstDelay,"score":0.0,"kills":0,"wavesCleared":0}
 relays.clear()
 for index in level.objectives.size():
  var record:Dictionary=level.objectives[index].duplicate(true);record.pos=_vector(record.pos)
  var id=str(record.get("id","relay_%d"%index));var short=id.right(1).to_upper() if not id.is_empty() else String.chr(65+index)
  var relay={"o":record,"id":id,"short":short,"t":0.0,"cut":false,"cutting":false}
  relay_changed.emit(relay,"live");relays.append(relay)
 if mode=="holdout":
  for relay in relays:relay_changed.emit(relay,"cut")
  relays.clear()
 run.relays=relays

# The surrounding game controller resets player/weapon/FX and handles intro/menu presentation.
func begin(mode:String="mission",keep_retries:bool=false,patrol:bool=true)->void:
 manager.clear();manager.combat.reset_stats();reset_run(mode,keep_retries)
 state="playing";state_changed.emit(state);objective_changed.emit(objective_text())
 if mode!="holdout" and patrol:spawn_patrol()

func reset_run(mode:String,keep_retries:bool=false)->void:
 var retries=int(run.get("retries",0)) if keep_retries else 0
 set_difficulty(difficulty);_new_run(mode,retries);debrief={};radio_cleared.emit();hud_reset.emit()

func choose_spawn(kind:String,min_distance:float=-1,origin:Variant=null,prefer_hidden:bool=true)->Vector3:
 if min_distance<0:min_distance=flow.spawnFar
 var from:Vector3=player.pos if origin==null else origin
 var category="air" if kind=="gull" else "ground";var candidates=[]
 for index in spawn_points.size():
  if spawn_points[index].type==category:candidates.append(index)
 if candidates.is_empty():
  for index in spawn_points.size():candidates.append(index)
 var selected=-1;var best=-1e9
 for index in candidates:
  var position:Vector3=spawn_points[index].pos;var distance=Vector2(position.x-from.x,position.z-from.z).length();var score=rng.randf()*1.5
  score+=2+minf(1,(distance-min_distance)/30)*.5 if distance>=min_distance else -(min_distance-distance)/4
  if prefer_hidden and not manager.coordinator.physics.line_of_sight(position+Vector3(0,0 if kind=="gull" else 1,0),player.eye):score+=2.5
  if run.used.has(index) and run.time-run.used[index]<6:score-=3
  if score>best:best=score;selected=index
 var result=Vector3.ZERO
 if selected>=0:
  run.used[selected]=run.time;result=spawn_points[selected].pos
  var dx=(rng.randf()-.5)*2.4;var dz=(rng.randf()-.5)*2.4
  if kind=="gull" or navigation.is_walkable(result.x+dx,result.z+dz):result.x+=dx;result.z+=dz
 else:
  var angle=rng.randf()*TAU;result=Vector3(clampf(from.x+cos(angle)*26,-34,26),0,clampf(from.z+sin(angle)*26,-26,24))
 if kind=="gull" and result.y<2.5:result.y=6+rng.randf()*3
 return result

func spawn_patrol()->void:
 var origin=_vector(level.playerStart.pos)
 for kind in ["gull","hound"]:
  for index in int(flow.patrol[kind]):manager.spawn(kind,choose_spawn(kind,32,origin,true),{"state":"patrol"})

func _warn_direction(types:Array,delay:float,stagger:float,label:String,duration:float)->void:
 var x=0.0;var z=0.0
 for index in types.size():
  var position=choose_spawn(types[index]);x+=position.x-player.pos.x;z+=position.z-player.pos.z
  run.queue.append({"type":types[index],"pos":position,"at":run.time+delay+index*stagger})
 run.waveHot=30
 var angle=fposmod(rad_to_deg(atan2(x,-z))+360,360);var direction=DIRECTIONS[int(floor(angle/45+.5))%8]
 warning.emit(label+direction,duration)

func queue_relay_wave(index:int)->void:
 var settings:Dictionary=flow.waves[mini(index,flow.waves.size()-1)];var types=[]
 for i in int(settings.gull):types.append("gull")
 for i in int(settings.hound):types.insert(mini(types.size(),1+i*2),"hound")
 _warn_direction(types,1.6,flow.spawnStagger,"Contact — ",3.4)

func process_queue(dt:float)->void:
 var alive=manager.alive_count()
 for index in run.queue.size():
  var item:Dictionary=run.queue[index]
  if run.time<item.at:continue
  if alive>=flow.maxAlive:item.at=run.time+1;continue
  var actor=manager.spawn(item.type,item.pos,{"state":"alert","target":player.pos})
  if actor==null:
   item.tries=item.get("tries",0)+1
   if item.tries<6:item.at=run.time+1.5;continue
  run.queue.remove_at(index);manager.alert(player.pos,60);break
 if run.allCut:
  run.pursuitT-=dt
  if run.pursuitT<=0 and run.pursuitLeft>0 and run.queue.is_empty() and alive<flow.pursuitMinAlive:
   run.pursuitT=flow.pursuitEvery;run.pursuitLeft-=1
   var kind="gull" if rng.randf()<.6 else "hound";run.queue.append({"type":kind,"pos":choose_spawn(kind),"at":run.time+.5})
  if run.pursuitT<=0:run.pursuitT=4;manager.alert(player.pos,90)

func nearest_relay()->Dictionary:
 var selected={};var nearest=float(flow.interactRange)
 for relay in relays:
  if relay.cut:continue
  var offset:Vector3=relay.o.pos-player.pos;var distance=Vector2(offset.x,offset.z).length()
  if distance>nearest or absf(offset.y)>2.5:continue
  if distance>.9 and (offset.x*player.forward.x+offset.z*player.forward.z)/(distance*maxf(.2,Vector2(player.forward.x,player.forward.z).length()))<flow.interactFacing:continue
  selected=relay;nearest=distance
 return selected

func interact(dt:float,held:bool)->void:
 var nearest=nearest_relay() if player.alive else {}
 for relay in relays:
  if relay.cut:continue
  if not nearest.is_empty() and relay.id==nearest.id and held:
   if not relay.cutting:relay.cutting=true;relay_changed.emit(relay,"cutting")
   relay.t+=dt/flow.cutSeconds;progress.emit(relay.id,minf(1,relay.t))
   if relay.t>=1:cut_relay(relay)
  elif relay.t>0:
   relay.t=maxf(0,relay.t-dt*1.6)
   if relay.cutting:relay.cutting=false;relay_changed.emit(relay,"live");progress.emit(relay.id,0)
 if not nearest.is_empty() and not nearest.cut:prompt_changed.emit("Cut relay "+nearest.short,clampf(nearest.t,0,1))
 else:prompt_changed.emit(null,0)
 var distance=Vector2(extraction.pos.x-player.pos.x,extraction.pos.z-player.pos.z).length()
 var inside=distance<float(extraction.get("radius",2.5)) and absf(extraction.pos.y-player.pos.y)<3.5
 if inside and run.allCut and player.alive and run.mode!="holdout":complete()
 elif inside and not run.allCut and run.mode!="holdout" and run.extractHint<=0:
  run.extractHint=8;message.emit("Relays still live — the boat will not wait under fire",3.5)
 run.extractHint=maxf(0,run.extractHint-dt)

func cut_relay(relay:Dictionary)->void:
 relay.cut=true;relay.cutting=false;relay.t=1;run.cut+=1;relay_changed.emit(relay,"cut")
 objective_done.emit(relay.id,run.cut,relays.size());prompt_changed.emit(null,0);player.shake=minf(1,player.shake+.18);queue_relay_wave(run.cut-1)
 if run.cut>=relays.size():run.allCut=true;run.pursuitLeft=flow.pursuitExtra;run.pursuitT=12;objective_all.emit();radio_requested.emit(rules.radio.all,4.5)
 else:radio_requested.emit(rules.radio.cut[mini(run.cut-1,rules.radio.cut.size()-1)],3.6)
 objective_changed.emit(objective_text())

func objective_text()->String:
 if run.mode=="holdout":return "Hold the berth" if run.waveOn else "Catch your breath" if run.wave else "Machines inbound"
 if run.allCut:return "Get to the boat"
 var remaining=relays.size()-run.cut
 return "Cut the three uplink relays" if run.cut==0 else "Cut the last relay" if remaining==1 else "Cut the remaining %d relays"%remaining

func complete()->void:
 player.invulnerable=true;player.enabled=false;prompt_changed.emit(null,0);radio_cleared.emit();radio_requested.emit(rules.radio.done,2.2)
 var stats:Dictionary=manager.combat.stats;var accuracy:Variant=clampf(float(stats.hits)/stats.shots,0,1) if stats.shots>0 else null
 var points=(2 if run.time<270 else 1 if run.time<400 else 0)+(2 if accuracy!=null and accuracy>=.5 else 1 if accuracy!=null and accuracy>=.3 else 0)+(1 if run.retries==0 else 0)
 debrief={"time":run.time,"accuracy":accuracy,"kills":stats.kills,"retries":run.retries,"rating":["Messy","Loud","Steady","Clean","Sharp","Surgical"][points]}
 state="complete";state_changed.emit(state)

func _on_player_dead()->void:
 if state in ["playing","paused"]:state="dead";prompt_changed.emit(null,0);radio_cleared.emit();state_changed.emit(state)
func _on_player_hit(_amount:float,_from:Variant)->void:run.alertT=maxf(run.alertT,8)
func _contact()->void:
 run.alertT=10
 if state=="playing" and not run.contactSaid:run.contactSaid=true;radio_requested.emit(rules.radio.contact,3.2)
func _on_alert(_state:Dictionary)->void:_contact()
func _on_noise_alert(_actor:Variant)->void:_contact()
func _on_killed(actor:Variant)->void:
 if run.mode!="holdout" or state!="playing":return
 run.kills+=1;run.score+=float(rules.holdout.killScore.get(actor.state.type,100))*(1+.1*(run.wave-1))

func update(dt:float,interact_held:bool=false)->void:
 if state!="playing":return
 run.time+=dt;interact(dt,interact_held)
 if state!="playing":return
 process_queue(dt)
 if run.mode=="holdout":_holdout_update(dt)
 run.alertT=maxf(0,run.alertT-dt);run.waveHot=maxf(0,run.waveHot-dt)
 var alive=manager.alive_count()
 if run.waveHot>0 and alive==0 and run.queue.is_empty() and run.waveHot<24:run.waveHot=0
 var close=false
 for actor in manager.active:
  if actor.state.alive and Vector2(actor.state.pos.x-player.pos.x,actor.state.pos.z-player.pos.z).length()<26:close=true;break
 run.intensity=1 if run.allCut or not run.queue.is_empty() or (run.waveHot>0 and alive>0) else .6 if run.alertT>0 or (alive>0 and close) else .15

 if not run.lowSaid and player.alive and player.health<30:run.lowSaid=true;radio_requested.emit(rules.radio.low,3)

func _holdout_update(dt:float)->void:
 if run.waveOn:
  if run.queue.is_empty() and manager.alive_count()==0:_finish_holdout_wave()
 else:
  run.breakT-=dt
  if run.breakT<=0:_start_holdout_wave()
  elif run.wave>0 and run.breakT<3.05 and ceil(run.breakT)!=ceil(run.breakT+dt):message.emit("Wave %d in %d"%[run.wave+1,int(ceil(run.breakT))],1)

func _start_holdout_wave()->void:
 run.wave+=1;var wave=int(run.wave);set_difficulty(difficulty);var tuning:Dictionary=manager.coordinator.tuning
 var hp=minf(2.5,1+.07*(wave-1));var damage=minf(2,1+.05*(wave-1));var cooldown=maxf(.6,1-.03*(wave-1))
 for kind in ["gull","hound"]:
  tuning[kind].hp=int(floor(tuning[kind].hp*hp+.5))
  for index in tuning[kind].cooldown.size():tuning[kind].cooldown[index]*=cooldown
 tuning.gull.boltDamage*=damage;tuning.hound.shotDamage*=damage;tuning.hound.lungeDamage*=damage
 flow.maxAlive+=mini(5,int(floor(float(wave)/2)))
 var count=mini(5+2*wave,30);var hounds=int(floor(count*minf(.45,.2+.03*wave)+.5));var types=[]
 for index in count:types.append("gull")
 for index in hounds:types[mini(count-1,1+int(floor(float(index*count)/maxi(1,hounds))))]="hound"
 _warn_direction(types,1.2,maxf(.35,.9-.04*wave),"Wave %d — "%wave,3.6)
 run.waveOn=true;objective_changed.emit("Hold the berth");wave_started.emit(wave,count)

func _finish_holdout_wave()->void:
 run.waveOn=false;run.wavesCleared=run.wave;run.breakT=rules.holdout.breather;run.score+=rules.holdout.waveBonus*run.wave
 resupply.emit(rules.holdout.resupply,rules.holdout.reserveCap,int(run.wave)%2==0);player.heal(rules.holdout.heal)
 radio_requested.emit("Wave %d down. Resupply dropped — %d seconds."%[run.wave,int(rules.holdout.breather)],3.4)
 objective_changed.emit("Catch your breath");objective_done.emit("wave",run.wave,run.wave)

func dispose()->void:
 if player.died.is_connected(_on_player_dead):player.died.disconnect(_on_player_dead)
 if player.hit.is_connected(_on_player_hit):player.hit.disconnect(_on_player_hit)
 if manager.coordinator.alerted.is_connected(_on_alert):manager.coordinator.alerted.disconnect(_on_alert)
 if manager.noise_alerted.is_connected(_on_noise_alert):manager.noise_alerted.disconnect(_on_noise_alert)
 for kind in manager.pools:
  for actor in manager.pools[kind]:
   if actor.killed.is_connected(_on_killed):actor.killed.disconnect(_on_killed)
