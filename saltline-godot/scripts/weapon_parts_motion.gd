extends RefCounted
# Original rig-private mechanical state, not hand targets or magazine trajectories.
const Math=preload("res://scripts/weapon_motion_math.gd")
var states:Dictionary={}
func _init()->void:reset_all()
func reset_all()->void:
 for gun in ["rifle","pistol"]:reset(gun)
func reset(gun:String)->void:
 states[gun]={"time":9.0,"locked":false,"round_visible":true,"override":0.0,"slide":0.0,"barrel_pitch":0.0,"barrel_z":0.0,"stop_weight":0.0,"stop_pitch":0.0,"finger":0.0}
func shot(gun:String,empty:bool)->void:
 var s:Dictionary=states[gun];s.time=0.0
 if empty:s.locked=true;s.round_visible=false
func set_locked(gun:String,value:bool)->void:
 var s:Dictionary=states[gun];s.locked=value;s.round_visible=not value
 if gun=="pistol" and value:s.time=9.0
func cancel_reload(gun:String,seated:bool,ammo:int)->void:
 if gun=="rifle":states[gun].override=0.0
 if seated:states[gun].locked=false
 states[gun].round_visible=ammo>0
func end_reload(gun:String)->void:
 if gun=="rifle":states[gun].override=0.0
func magazine_fresh(gun:String)->void:states[gun].round_visible=true
func reload_event(gun:String,phase:String,empty:bool)->void:
 if gun=="rifle":
  if phase=="magin" and not empty:states[gun].locked=false
  if phase in ["boltback","bolt"]:states[gun].locked=false
  if phase=="bolt":states[gun].override=0.0
 elif phase=="slide":states[gun].locked=false
func rifle_handle(time:float,empty:bool)->void:
 var back=1.96 if empty else 1.89;var release=2.12 if empty else 1.905;var bolt=2.155 if empty else 1.93;var amount=1.0 if empty else .32
 var value=0.0
 if time<1.84:value=0.0
 elif time<back:value=amount*Math.ease(clampf((time-1.84)/(back-1.84),0,1))
 elif time<release:value=amount
 else:value=amount*maxf(0,1.0-(time-release)/(bolt-release))
 states.rifle.override=value
func slide_position(value:float)->void:
 states.pistol.slide=value
 var amount=minf(1,value/.006);states.pistol.barrel_pitch=.02*amount;states.pistol.barrel_z=.0025*amount
func pistol_reload_pose(time:float,empty:bool)->void:
 if not empty:return
 states.pistol.stop_weight=1.0 if time<1.53 else 1.0-Math.ease(clampf((time-1.53)/(1.575-1.53),0,1))
 slide_position(.036 if time<1.575 else .036*maxf(0,1.0-(time-1.575)/(1.61-1.575)))
func step(gun:String,dt:float,finger:float,reloading:bool)->void:
 var s:Dictionary=states[gun];s.time+=dt
 if gun=="rifle":
  var wave=sin(PI*s.time/.072) if s.time<.072 else 0.0
  if s.locked and s.time>.036:wave=maxf(wave,0.0) # Original yS=0.
  s.slide=.062*maxf(wave*.95,s.override)
 else:
  if not (reloading and s.locked):
   var wave=(s.time/.024 if s.time<.024 else 1.0-(s.time-.024)/(.066-.024)) if s.time<.066 else 0.0
   if s.locked and s.time>.024:wave=maxf(wave,.036/.04)
   slide_position(.04*wave);s.stop_weight=1.0 if s.locked and s.time>.03 else 0.0
  s.stop_pitch=-.06*s.stop_weight
 s.finger=finger
