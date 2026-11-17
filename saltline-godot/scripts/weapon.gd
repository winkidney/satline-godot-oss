class_name SaltlineWeapon
extends RefCounted

signal fired(weapon:String,definition:Dictionary,spread:float)
signal phase_event(event:String,weapon:String,phase:String)
signal smoke_requested(options:Dictionary)

const TIMINGS={
 "rifle":{"tac":2.24,"empty":2.72,"magout":.4,"maginsert":1.15,"magin":1.44,"boltback_tac":1.89,"boltback_empty":1.96,"bolt_tac":1.93,"bolt_empty":2.155},
 "pistol":{"tac":1.5,"empty":1.9,"magout":.18,"maginsert":.9,"magin":1.13,"slide":1.61}
}
var rigs:Dictionary
var slots:Dictionary={}
var current="rifle"
var pending=""
var state="idle"
var time=0.0
var cooldown=0.0
var previous_fire=false
var fire_queue=0.0
var dry_done=false
var auto_reload=-1.0
var last_shot=-9.0
var burst=0
var bloom=0.0
var heat=0.0
var spread=.0125
var ads_linear=0.0
var ads=0.0
var sprint_blend=0.0
var reload:Dictionary={}
var switching:Dictionary={}
var holster=0.0
var shot_count=0
# Shared motion state; some legacy logic fields still have separate owners.
var motion_state:Dictionary
var motion_lifecycle
var reload_motion
var motion_controls
var motion_inspect:Array=[0.0,0.0,0.0]
var motion_rng
var startup_info={}
var root_motion
var bloom_shot=-1
var live_root_steps=0
var parts_motion=preload("res://scripts/weapon_parts_motion.gd").new()
var magazine_motion
var reload_hand
var arms
var visible=true
var view=1
var presentation:WeakRef
var debug_reload_time:Variant=null
var debug_flash=false
var debug_reload_empty=false

func _init(data:Dictionary,initial_state:Dictionary={},random_seed:int=-1,random_stream:SaltlineSourceRng=null)->void:
 rigs=data.rigs.duplicate(true)
 var startup=preload("res://scripts/weapon_startup.gd")
 motion_state=startup.state() if initial_state.is_empty() else initial_state.duplicate(true)
 var seed_value=random_stream.seed if random_stream!=null else startup.weapon_seed() if random_seed<0 else random_seed
 motion_rng=random_stream if random_stream!=null else preload("res://scripts/source_rng.gd").new(seed_value)
 startup_info={"mode":"canonical" if initial_state.is_empty() else "explicit_state","seed_mode":"shared_stream" if random_stream!=null else "canonical_fork" if random_seed<0 else "explicit_seed","weapon_seed":seed_value,"world_seed":4207}
 magazine_motion=preload("res://scripts/weapon_magazine_motion.gd").new(rigs)
 reload_hand=preload("res://scripts/weapon_reload_hand.gd").new(rigs,JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-reload-hand-poses.json")),magazine_motion)
 arms=preload("res://scripts/weapon_arms.gd").new(rigs)
 time=float(motion_state.t) # Canonical cold state, or an explicit isolated-test state.
 root_motion=preload("res://scripts/weapon_root_motion.gd").new(motion_state,motion_rng.randf,true)
 motion_lifecycle=preload("res://scripts/weapon_motion_lifecycle.gd").new(motion_state,rigs)
 reload_motion=preload("res://scripts/weapon_reload_motion.gd").new(motion_state,self)
 reload_motion.parts_motion=parts_motion
 reload_motion.magazine_motion=magazine_motion
 reload_motion.reload_hand=reload_hand
 reload_motion.arms=arms
 motion_controls=preload("res://scripts/weapon_motion_controls.gd").new(motion_state)
 for id in rigs:
  var definition:Dictionary=rigs[id].def
  slots[id]={"ammo":int(definition.magSize),"reserve":INF if definition.reserve is Dictionary else float(definition.reserve),"mag_size":int(definition.magSize)}

func smoother(value:float)->float:
 var x=clampf(value,0,1)
 return x*x*x*(x*(6*x-15)+10)

func on_player_motion_event(kind:String,payload:Dictionary)->void:
 match kind:
  "step":motion_state.stepEv=1
  "jump":motion_state.jumpEv=1
  "land":motion_state.landEv=maxf(0,float(payload.get("speed",0.0)))

func motion_randf()->float:return root_motion.random()
func step_root(dt:float,input:Dictionary,player:SaltlinePlayer)->Transform3D:
 var state={"onGround":player.on_ground,"speed":player.speed,"vel":{"x":player.velocity.x,"y":player.velocity.y,"z":player.velocity.z},"yaw":player.yaw,"eye":player.eye,"forward":player.forward,"crouching":player.crouching,"sprinting":player.sprinting,"tuning":player.tuning}
 var physics=player.physics
 var ray=func(origin,direction,distance):
  var hit=physics.raycast(origin,direction,distance)
  return null if hit.is_empty() else hit
 live_root_steps+=1
 var transform=root_motion.step(dt,rigs[current],state,input,motion_inspect,ray)
 arms.step(dt,self,transform)
 return transform
func sample_spread(value:float)->Vector3:
 var angle=motion_randf()*TAU;var radius=tan(value)*sqrt(motion_randf())
 return Vector3(cos(angle)*radius,sin(angle)*radius,-1).normalized()
func sample_shell_velocity()->Vector3:
 return Vector3(2+motion_randf()*1.2,1.2+motion_randf()*.8,.5-motion_randf()*.6)
func apply_recoil(player:Variant)->void:
 var scale=1.0+(.55-1.0)*ads
 scale*=.85 if player.crouching else 1.0
 root_motion.recoil(current,rigs[current],burst,scale,player.crouching,player.add_recoil,player.add_shake)
 _apply_shot_bloom()

func _apply_shot_bloom()->void:
 if bloom_shot==shot_count:return
 bloom_shot=shot_count;bloom=minf(1,bloom+rigs[current].def.spread.shot);motion_state.bloom=bloom

func reload_now()->bool:
 var slot:Dictionary=slots[current]
 if not reload.is_empty() or not switching.is_empty() or slot.ammo>=slot.mag_size or slot.reserve<=0:return false
 _begin_reload(slot.ammo<=0,true)
 return true

func _begin_reload(empty:bool,emit_start:bool)->void:
 var duration=TIMINGS[current].empty if empty else TIMINGS[current].tac
 var flags={}
 reload={"t":0.0,"T":duration,"weapon":current,"empty":empty,"fresh":true,"seated":false,"f":flags,"events":flags}
 motion_state.reload=reload;reload_motion.events.clear();reload_motion.arm_impulses=0
 auto_reload=-1
 if emit_start:phase_event.emit("reload",current,"start")

func _reload_event(context:Dictionary,name:String,at:float,_extra:Dictionary={})->bool:
 if context.t<at or context.f.get(name,false):return false
 context.f[name]=1
 if name=="magin":
  var slot:Dictionary=slots[context.weapon]
  var count=minf(slot.mag_size-slot.ammo,slot.reserve)
  slot.ammo+=int(count);slot.reserve-=count;context.seated=true
 phase_event.emit("reload",context.weapon,name)
 return true

func switch_to(id:String)->bool:
 if not rigs.has(id):return false
 if not switching.is_empty():
  if switching.phase=="holster":
   if pending==id:return false
   pending=id;return true
  if current==id:return false
  _start_switch(id,.28*(1-clampf(switching.t/.32,0,1)));return true
 if current==id:return false
 _start_switch(id,0);return true

func cancel_reload()->void:
 if not reload.is_empty():
  parts_motion.cancel_reload(reload.weapon,reload.seated,slots[reload.weapon].ammo)
  magazine_motion.reset(reload.weapon)
  arms.blend.blend(.22)
  reload_hand.reset(reload.weapon)
 reload={};motion_state.reload=null

func _start_switch(id:String,elapsed:float)->void:
 cancel_reload()
 auto_reload=-1;fire_queue=0
 motion_state.inspect=-1
 switching={"phase":"holster","t":elapsed,"fresh":true,"from":current}
 pending=id;phase_event.emit("switch",current,"holster")

func _equip(id:String)->void:
 var previous=current
 current=id;cooldown=0;fire_queue=0;dry_done=false;burst=0;bloom=0;heat=0;ads_linear=0;ads=0;auto_reload=-1
 motion_lifecycle.equip(id)
 if presentation!=null and presentation.get_ref()!=null:presentation.get_ref().sync_equip(self,previous)

func _switch_update(dt:float)->void:
 if switching.fresh:switching.fresh=false
 else:switching.t+=dt
 if switching.phase=="holster":
  if switching.t>=.28:
   var elapsed=minf(switching.t-.28,.16)
   arms.blend.blend(.13)
   _equip(pending);switching.phase="draw";switching.t=elapsed
   phase_event.emit("switch",current,"draw")
  else:holster=pow(clampf(switching.t/.28,0,1),2)
 if switching.phase=="draw":
  if switching.t>=.32:switching={};pending="";holster=0
  else:
   var x=clampf(switching.t/.32,0,1)-1
   holster=-(2.25*x*x*x+1.25*x*x)

func _shoot()->void:
 slots[current].ammo-=1;burst+=1;last_shot=time;heat=minf(1.3,heat+.05);shot_count+=1
 motion_state.burst=burst;motion_state.lastShot=last_shot
 fired.emit(current,rigs[current].def,spread)
 _apply_shot_bloom() # Fallback for weapon-only clients without a recoil receiver.
 parts_motion.shot(current,slots[current].ammo<=0)
 arms.shot(current)

func update(dt:float,input:Dictionary,player:Variant)->void:
 var alive=bool(player.get("alive",true)) if player is Dictionary else bool(player.alive)
 if not alive:previous_fire=false;return
 time+=dt
 motion_state.t=time
 if input.get("swap",false):switch_to("pistol" if (pending if pending!="" else current)=="rifle" else "rifle")
 elif input.get("weapon1",false):switch_to("rifle")
 elif input.get("weapon2",false):switch_to("pistol")
 if not switching.is_empty():_switch_update(dt)
 var definition:Dictionary=rigs[current].def
 var slot:Dictionary=slots[current]
 var busy_switch=not switching.is_empty()
 var fire=bool(input.fire) and visible
 var edge=fire and not previous_fire
 previous_fire=fire
 if not fire:dry_done=false
 var sprint=player.sprinting and not fire and not input.ads and reload.is_empty()
 sprint_blend=motion_controls.damp(sprint_blend,1.0 if sprint else 0.0,9,dt)
 motion_state.sprintT=sprint_blend;motion_state.hol=holster
 motion_controls.targets(sprint,fire,bool(input.ads),not reload.is_empty())
 if input.get("reload",false):reload_now()
 if auto_reload>=0:
  auto_reload-=dt
  if auto_reload<0:reload_now()
 if debug_reload_time!=null and reload.is_empty():_begin_reload(debug_reload_empty,false)
 if not reload.is_empty():
  var active_reload=reload
  if debug_reload_time!=null:active_reload.t=float(debug_reload_time)
  elif active_reload.fresh:active_reload.fresh=false
  else:active_reload.t+=dt
  reload_motion.step(active_reload.weapon,active_reload,active_reload.t)
  if active_reload.t>=active_reload.T and debug_reload_time==null:
   parts_motion.end_reload(active_reload.weapon)
   magazine_motion.reset(active_reload.weapon)
   reload_hand.reset(active_reload.weapon)
   reload={};motion_state.reload=null;reload_motion.clear_targets();phase_event.emit("reload",active_reload.weapon,"done")
 else:reload_motion.clear_targets()
 cooldown-=dt
 var can_fire=reload.is_empty() and not busy_switch and sprint_blend<.45
 if definition.auto:
  if fire and can_fire:
   if slot.ammo>0:
    var count=0
    while cooldown<=0 and slot.ammo>0 and count<3:
     _shoot();cooldown+=60/definition.rpm;count+=1
   elif not dry_done:
    dry_done=true;phase_event.emit("dry",current,"");motion_controls.dry()
    if slot.reserve>0:auto_reload=.32
 else:
  if edge:fire_queue=.13
  elif fire_queue>0:fire_queue-=dt
  if fire_queue>0 and can_fire and cooldown<=0:
   fire_queue=0
   if slot.ammo>0:_shoot();cooldown=60/definition.rpm
   else:
    phase_event.emit("dry",current,"");motion_controls.dry();cooldown=.12
    if slot.reserve>0:auto_reload=.28
 cooldown=maxf(cooldown,-.001)
 if time-last_shot>.24:
  if burst>0:motion_state.recPhase=motion_randf()*6.28
  burst=0
 bloom=maxf(0,bloom-dt*definition.spread.decay)
 if definition.get("smoke",false) and time-last_shot>.11 and time-last_shot<.11+dt*1.5 and heat>.4:motion_state.smoke=minf(1.6,heat*1.3)
 if float(motion_state.get("smoke",0))>0:
  motion_state.smoke-=dt;motion_state.smokeTick=float(motion_state.get("smokeTick",0))-dt
  if motion_state.smokeTick<=0 and smoke_requested.has_connections():
   motion_state.smokeTick=.085
   smoke_requested.emit({"size":.1+motion_state.smoke*.06,"life":1.3,"rise":.5,"count":1,"alpha":.22})
 heat=maxf(0,heat-dt*.2);motion_state.heat=heat
 var aim=input.ads and reload.is_empty() and not busy_switch and sprint_blend<.35
 ads_linear=clampf(ads_linear+(dt if aim else -dt)/definition.adsTime,0,1);ads=smoother(ads_linear)
 motion_state.adsWant=bool(aim);motion_state.adsLin=ads_linear;motion_state.adsE=ads
 var spec:Dictionary=definition.spread
 var target=lerpf(spec.hip,spec.ads,ads)+clampf(player.speed/6,0,1)*lerpf(spec.moveHip,spec.moveAds,ads)+bloom*lerpf(spec.bloomHip,spec.bloomAds,ads)+(spec.air if not player.on_ground else 0)-(spec.crouch*(1-ads) if player.crouching else 0)
 spread=motion_controls.damp(spread,target,18,dt)
 motion_inspect=motion_controls.finish(dt,definition,input,float(player.speed),busy_switch,fire,can_fire,debug_flash)
 parts_motion.step(current,dt,motion_state.finger,not reload.is_empty())
 state="switching" if busy_switch else "reloading" if not reload.is_empty() else "inspect" if motion_state.inspect>=0 else "sprinting" if sprint_blend>.5 else "firing" if time-last_shot<.14 else "idle"

func reset()->void:
 arms.reset()
 parts_motion.reset_all()
 magazine_motion.reset_all()
 reload_hand.reset("rifle");reload_hand.reset("pistol")
 motion_lifecycle.reset();reload_motion.events.clear();reload_motion.arm_impulses=0
 motion_inspect=[0.0,0.0,0.0]
 for id in rigs:
  var definition:Dictionary=rigs[id].def;slots[id].ammo=int(definition.magSize);slots[id].reserve=INF if definition.reserve is Dictionary else float(definition.reserve)
 current="rifle";pending="";state="idle";cooldown=0;previous_fire=false;fire_queue=0;dry_done=false;auto_reload=-1;last_shot=-9;burst=0;bloom=0;heat=0;ads_linear=0;ads=0;sprint_blend=0;reload={};switching={};holster=0
 # Source keeps a.t and the spread smoother when resetting a run.

func bind_presentation(renderer:Object)->void:presentation=weakref(renderer)
func equip(id:String)->void:
 if not rigs.has(id):return
 cancel_reload();switching={};pending="";holster=0.0;motion_state.hol=0.0
 var previous_ads=ads
 _equip(id);ads=previous_ads;arms.blend.snap()
func set_visible(value:bool)->void:
 visible=value;arms.set_visible(value)
 if presentation!=null and presentation.get_ref()!=null:presentation.get_ref().sync_visibility(self)
func set_view(value:Variant)->int:
 var number=0.0
 if value is String:number=value.to_float()
 elif value is float or value is int or value is bool:number=float(value)
 if is_nan(number):number=1.0
 view=int(floor(clampf(number,1,3)+.5))
 for gun in rigs:
  var index=clampi(view-1,0,rigs[gun].views.size()-1)
  rigs[gun].view=index;rigs[gun].pose=rigs[gun].views[index]
 return view
func add_ammo(amount:float)->void:slots[current].reserve+=amount
func snap(player:Variant,input:Dictionary,debug_ads:bool=false,debug_sprint:bool=false)->void:
 var state:Dictionary=player if player is Dictionary else {"sprinting":player.sprinting,"onGround":player.on_ground,"crouching":player.crouching}
 motion_lifecycle.snap(state,input,not switching.is_empty(),debug_ads,debug_sprint)
 ads_linear=motion_state.adsLin;ads=motion_state.adsE;sprint_blend=motion_state.sprintT
 for gun in rigs:arms.targeter.snap(gun,motion_state)
 arms.blend.snap()
func set_wetness(value:float)->void:
 var wetness=0.0 if is_nan(value) else clampf(value,0,1)
 if presentation!=null and presentation.get_ref()!=null:presentation.get_ref().set_wetness(wetness)
