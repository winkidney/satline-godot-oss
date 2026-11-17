extends RefCounted
# Literal D algorithm, original bundle-1.js 79801–80128. State is shared by rigs.
# External O owns time, wants, recoil/reload impulses, events and reset/equip.
const Math=preload("res://scripts/weapon_motion_math.gd")
var a:Dictionary
var random_source:Callable
var random_calls=0
var wall_queries=0
var no_idle=false

func _init(initial:Dictionary,random:Callable,share_state:bool=false)->void:
 a=initial if share_state else initial.duplicate(true);random_source=random

func en(state:Dictionary,target:float,dt:float,w:float=-1,z:float=-1)->float:
 return Math.advance(state,target,dt,w,z)
func snap(state:Dictionary,target:float)->void:
 if absf(state.x-target)<1e-5 and absf(state.v)<1e-4:Math.reset(state,target)
func damp(value:float,target:float,rate:float,dt:float)->float:
 return target+(value-target)*exp(-rate*dt)
func mix(x:float,y:float,t:float)->float:return x+(y-x)*t
func fs(value:float)->float:
 return -(.9*sin(value)+.318*sin(2.0*value)+.1*sin(3.0*value))*.9416
func random()->float:
 random_calls+=1
 return random_source.call()

func recoil(gun:String,rig:Dictionary,burst:int,camera_scale:float,crouching:bool,add_recoil:Callable=Callable(),add_shake:Callable=Callable())->void:
 # Original rig recoil methods, 77017–77039 and 78679–78696.
 # Camera scale does not multiply the root impulses in the original.
 var config:Dictionary=rig.motion.recoil
 var ads=float(a.adsE);var strength:float
 if gun=="rifle":
  var burst_scale=1.0 if burst<=9 else .38
  var yaw=((random()-.5)*.0022 if burst<4 else sin(burst*.57+a.recPhase)*.0042+(random()-.5)*.002)*camera_scale
  if add_recoil.is_valid():add_recoil.call(.0068*burst_scale*camera_scale*(.85+random()*.3),yaw)
  if add_shake.is_valid():add_shake.call(.12*camera_scale)
  var first=config.first if burst==1 else .5+.5*config.first if burst==2 else 1.0
  strength=first*(.88+random()*.24)*(.88 if crouching else 1.0)
 else:
  if add_recoil.is_valid():add_recoil.call(.0092*camera_scale*(.9+random()*.2),(random()-.5)*.005*camera_scale)
  if add_shake.is_valid():add_shake.call(.14*camera_scale)
  strength=(.9+random()*.2)*(.9 if crouching else 1.0)
 var rotation=strength*mix(1,config.adsRot,ads);var position=strength*mix(1,config.adsPos,ads)
 a.kZ.v+=config.back*strength*mix(1,config.adsBack,ads);a.kP.v+=config.rise*rotation
 a.kY.v+=(random()-.5)*config.yaw*rotation;a.kR.v+=(random()-.5)*config.roll*rotation
 a.kU.v+=config.up*position*((.7+.6*random()) if gun=="rifle" else 1.0)
 a.kX.v+=(random()-.5)*2.0*config.side*position

func step(dt:float,rig:Dictionary,player:Dictionary,input:Dictionary,inspect:Array=[0.0,0.0,0.0],raycast:Callable=Callable())->Transform3D:
 var B=minf(dt,.1);var ye:Dictionary=rig.motion;var pose:Dictionary=rig.pose
 var ground_value=player.get("onGround",true)
 var grounded=not (ground_value is bool and ground_value==false);var speed=float(player.get("speed",0.0))
 var velocity:Dictionary=player.vel if player.get("vel") is Dictionary else {};var vx=float(velocity.get("x",0));var vy=float(velocity.get("y",0));var vz=float(velocity.get("z",0));var time=float(a.t)
 var ads_target=1.0 if a.adsWant else 0.0
 en(a.adsV,ads_target,B,ye.ads.w,ye.ads.z);snap(a.adsV,ads_target)
 en(a.adsS,ads_target,B);snap(a.adsS,ads_target)
 var ads_difference=a.adsS.x-a.adsV.x;var ads_out=ads_difference*ads_difference*ye.ads.out if ads_difference>0 else 0.0
 var sprint_target=1.0 if a.spWant else 0.0
 en(a.spV,sprint_target,B,ye.sprint.spr[0]*(1.5 if a.urgent else 1.0),ye.sprint.spr[1]);snap(a.spV,sprint_target)
 en(a.rwS,a.reloadW,B);snap(a.rwS,a.reloadW);en(a.rkS,a.rackW,B);snap(a.rkS,a.rackW)
 var ads=float(a.adsV.x);var ads_clamped=clampf(ads,0,1);var q0=ads_clamped*ads_clamped*(3.0-2.0*ads_clamped);var ads_arc=4.0*ads*(1.0-ads)
 var sprint=float(a.spV.x);var sprint_arc=4.0*sprint*(1.0-sprint);var hol=float(a.hol)
 var hol_xz=hol*(1.6-.6*absf(hol));var hol_y=hol*(.35+.65*absf(hol));var hol_r=hol*(1.45-.45*absf(hol))
 a.wallT-=B
 if a.wallT<=0 and raycast.is_valid() and player.get("eye")!=null and player.get("forward")!=null:
  a.wallT=.08;wall_queries+=1
  var hit=raycast.call(player.eye,player.forward,ye.wall.far)
  a.wallK=Math.ease((ye.wall.far-hit.dist)/(ye.wall.far-ye.wall.near)) if hit!=null else 0.0
 en(a.wall,a.wallK,B);snap(a.wall,a.wallK)
 var wall=a.wall.x*(1.0-.85*q0)*(1.0-clampf(hol*hol,0,1))
 var base_p=[];var base_r=[];var hol_p=[.085,-.34,.07];var hol_rot=[-.5,.22,-.42]
 for axis in 3:
  base_p.append(pose.HIP.p[axis]+(pose.ADS.p[axis]-pose.HIP.p[axis])*ads+ye.ads.arc.p[axis]*ads_arc+pose.SPRINT.p[axis]*sprint+pose.SPRINT_ARC.p[axis]*sprint_arc+pose.RELOAD.p[axis]*a.rwS.x+pose.RACK.p[axis]*a.rkS.x+hol_p[axis]*(hol_y if axis==1 else hol_xz)+ye.wall.p[axis]*wall)
  base_r.append(pose.HIP.r[axis]*(1.0-ads)+ye.ads.arc.r[axis]*ads_arc+pose.SPRINT.r[axis]*sprint+pose.SPRINT_ARC.r[axis]*sprint_arc+pose.RELOAD.r[axis]*a.rwS.x+pose.RACK.r[axis]*a.rkS.x+hol_rot[axis]*hol_r+ye.wall.r[axis]*wall)
 base_p[0]-=.035*inspect[2];base_p[1]+=.045*inspect[2]
 base_r[0]+=.3*inspect[2];base_r[1]+=.18*inspect[2]+.25*inspect[1];base_r[2]+=-.75*inspect[0]+.55*inspect[1]
 var px=0.0;var py=0.0;var pz=0.0;var rx=0.0;var ry=0.0;var rz=0.0
 var position_scale=mix(1,ye.ads.pos,q0);var rotation_scale=mix(1,ye.ads.rot,q0)
 if not no_idle:
  var idle:Dictionary=ye.idle;var exert=float(a.exert);var pscale=position_scale*(1.0-.5*sprint)
  a.exert=damp(a.exert,1.0 if player.get("sprinting",false) else 0.0,.3 if player.get("sprinting",false) else .14,B)
  a.breath+=B*TAU*idle.hz*(1.0+.5*exert)*(1.0+.1*Math.noise(time*.11,3))
  if a.breath>4096:a.breath-=651.0*TAU
  var breath=float(a.breath);var amplitude=(1.0+.9*exert)*(1.0+.2*Math.noise(time*.07,5))
  var wave=(sin(breath)+.24*sin(2.0*breath+.7))*amplitude;var wave_p=(sin(breath-.6)+.2*sin(2.0*breath+.2))*amplitude
  var drift=1.4*Math.noise(time*.09,7);var drift2=1.4*Math.noise(time*.08,8)
  px+=(sin(time*.53+drift)*idle.drift+wave*idle.breathY*.15+Math.noise(time*2.3,12)*idle.noise)*pscale
  py+=(wave*idle.breathY+sin(time*.83+1.7+drift2)*idle.drift*.6+Math.noise(time*1.9,11)*idle.noise)*pscale
  rx+=(wave_p*idle.breathP+sin(time*.41+.9+drift2)*idle.driftR*.5+Math.noise(time*1.6,13)*idle.noiseR)*rotation_scale
  ry+=(sin(time*.37+2.2+drift)*idle.driftR+Math.noise(time*1.3,14)*idle.noiseR)*rotation_scale
  rz+=(sin(time*.29+.4-drift)*idle.driftR*.8+Math.noise(time*1.1,15)*idle.noiseR)*rotation_scale
 var tuning:Dictionary=player.tuning if player.get("tuning") is Dictionary else {}
 var strides:Dictionary=tuning.stride if tuning.get("stride") is Dictionary else {"walk":1.55,"sprint":2.1,"crouch":1.05}
 var stride=en(a.stride,strides.crouch if player.get("crouching",false) else strides.sprint if player.get("sprinting",false) else strides.walk,B)
 a.spd=damp(a.spd,speed,14,B)
 var phase=a.gait+a.gOff.x
 if grounded:
  var moving=clampf(speed/.5,0,1)
  a.gait+=(moving*speed*B)/stride-(((1.0-moving)*sin(TAU*phase))/TAU)*(1.0-exp(-8.0*B))
 if a.landEv>=0 or (not a.wasGround and grounded):a.gOffT+=floor(phase)+.35-phase
 elif a.stepEv:
  var increment=(speed*B)/stride
  var correction=floor(phase+.5)-phase-increment*.5 # JavaScript Math.round, including negative ties.
  if absf(correction)>.55*increment:a.gOffT+=correction-(a.gOffT-a.gOff.x)
 a.stepEv=0;en(a.gOff,a.gOffT,B)
 if a.gait>2048:a.gait-=2048
 en(a.amt,pow(clampf(speed/3.8,0,1),.8)*(ye.crouch if player.get("crouching",false) else 1.0) if grounded else 0.0,B)
 var walk:Dictionary=ye.walk;var run:Dictionary=ye.run;var amount=float(a.amt.x)
 var gait=a.gait+a.gOff.x-(mix(walk.lag,run.lag,sprint)*a.spd)/stride
 var phase2=TAU*gait-.965;var phase_half=PI*gait
 var pweight=amount*mix(1,.14,q0);var rweight=amount*mix(1,.05,q0)
 px+=(sin(phase_half)+.16*sin(3.0*phase_half+.5))*mix(walk.x,run.x,sprint)*pweight
 py+=fs(phase2)*mix(walk.y,run.y,sprint)*pweight
 pz+=(sin(phase2+.965+2.2)+.25*sin(phase_half+.4))*mix(walk.z,run.z,sprint)*pweight
 rx+=fs(phase2-.55)*mix(walk.pitch,run.pitch,sprint)*rweight
 ry+=(sin(phase_half+1.25)+.22*sin(phase2+.965))*mix(walk.yaw,run.yaw,sprint)*rweight
 rz+=(sin(phase_half+.35)+.25*sin(phase2+.965+1.0))*mix(walk.roll,run.roll,sprint)*rweight
 var inertia:Dictionary=ye.inertia;var yaw=float(player.get("yaw",0));var cosine=cos(yaw);var sine=sin(yaw)
 var right=vx*cosine-vz*sine;var forward=-vx*sine-vz*cosine;var smooth=1.0-exp(-B/inertia.tau)
 a.lpR+=(right-a.lpR)*smooth;a.lpF+=(forward-a.lpF)*smooth
 var delta_right=right-a.lpR;var delta_forward=forward-a.lpF;var ip=mix(1,.3,q0);var ir=mix(1,.08,q0)
 pz+=en(a.inZ,delta_forward*inertia.z,B)*ip;px+=en(a.inX,-delta_right*inertia.x,B)*ip
 rx+=en(a.inP,delta_forward*inertia.pitch,B)*ir;rz+=en(a.inR,-delta_right*inertia.roll-a.lpR*inertia.lean*(1.0-sprint),B)*ir
 var sway:Dictionary=ye.sway;var sway_impulse=sway.spr[0]*sway.spr[0]*sway.lag;var sway_limit=sway.max*2.5;var look:Dictionary=input.look if input.get("look") is Dictionary else {}
 a.swY.v+=clampf(look.get("dx",0),-.35,.35)*sway_impulse;a.swP.v+=clampf(look.get("dy",0),-.35,.35)*sway_impulse*.8
 en(a.swY,0,B);en(a.swP,0,B)
 for state in [a.swY,a.swP]:
  if state.x>sway_limit or state.x< -sway_limit:state.x=clampf(state.x,-sway_limit,sway_limit);state.v=0.0
 var sy=Math.soft_limit(a.swY.x,sway.max);var sp=Math.soft_limit(a.swP.x,sway.max*.75)
 var sr=mix(1,sway.adsRot,q0);var st=mix(1,sway.adsPos,q0)
 ry+=sy*sr;rz-=sy*sway.roll*sr;rx+=sp*sr;px-=sy*sway.shift*st;py+=sp*sway.shift*st
 var air:Dictionary=ye.air;var air_p=mix(1,.45,q0);var air_r=mix(1,.1,q0)
 if a.wasGround and not grounded and (a.jumpEv or vy>1):a.jY.v+=air.jumpY;a.jP.v+=air.jumpP
 if not a.wasGround and grounded:
  var landing=clampf(maxf(a.landEv,-a.lastVy),0,14)
  a.landSide=-a.landSide;a.jY.v-=landing*air.landY;a.jP.v-=landing*air.landP;a.jR.v+=a.landSide*landing*air.landR*(.65+.35*random())
 a.wasGround=grounded;a.jumpEv=0;a.landEv=-1
 if not grounded:a.lastVy=vy
 var crouch:Dictionary=ye.crouchDip;var crouch_target=1.0 if player.get("crouching",false) else 0.0
 var stance=(en(a.stance,crouch_target,B,crouch.w[0],1)-en(a.stance2,crouch_target,B,crouch.w[1],1))*2.4
 py-=stance*crouch.y*air_p;rx-=stance*crouch.pitch*air_r;rz+=stance*crouch.roll*air_r
 py+=en(a.jY,0.0 if grounded else clampf(-vy*air.fallY,-.004,.016),B)*air_p
 rx+=en(a.jP,0.0 if grounded else clampf(-vy*air.fallP,-.02,.04),B)*air_r;rz+=en(a.jR,0,B)*air_r
 for state in [a.kZ,a.kP,a.kY,a.kR,a.kX,a.kU,a.bump]:en(state,0,B)
 en(a.antY,a.antYT,B);en(a.antR,a.antRT,B)
 rx+=a.kP.x+a.bump.x*1.5;ry+=a.kY.x;rz+=a.kR.x+a.antR.x;py+=a.bump.x*.6+a.antY.x
 var base=Basis.from_euler(Vector3(base_r[0],base_r[1],base_r[2]),EULER_ORDER_YXZ).get_rotation_quaternion()
 var detail=Basis.from_euler(Vector3(rx,ry,rz),EULER_ORDER_YXZ).get_rotation_quaternion()
 var pivot=Vector3(ye.pivot[0],ye.pivot[1],ye.pivot[2]);var delta=pivot-detail*pivot
 var offset=base*(delta+Vector3(a.kX.x,a.kU.x,a.kZ.x-ads_out))
 return Transform3D(Basis(base*detail),Vector3(base_p[0]+px,base_p[1]+py,base_p[2]+pz)+offset)
