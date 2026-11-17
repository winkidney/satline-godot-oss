extends RefCounted
const Math=preload("res://scripts/weapon_motion_math.gd")
var m
var targets={}
var poses:Dictionary
var release_pose=Transform3D.IDENTITY
var shared_magazine=false
var thumb_weight=0.0
func _init(rigs:Dictionary,source_poses:Dictionary,magazine=null)->void:
 shared_magazine=magazine!=null
 m=magazine if shared_magazine else preload("res://scripts/weapon_magazine_motion.gd").new(rigs)
 poses=source_poses
 reset("rifle");reset("pistol")
func mix_pose(a,b,t:float)->PackedFloat32Array:
 var output=PackedFloat32Array();output.resize(20)
 for j in 20:output[j]=a[j]+(b[j]-a[j])*t
 return output
func three_pose(a,b,c,t:float)->PackedFloat32Array:
 return mix_pose(a,b,Math.ease(t*2)) if t<.5 else mix_pose(b,c,Math.ease(t*2-1))
func write(gun:String,tr:Transform3D,fingers,busy:bool=true)->void:
 targets[gun]={"p":tr.origin,"q":tr.basis.get_rotation_quaternion(),"pose":PackedFloat32Array(fingers),"busy":busy}
func reset(gun:String)->void:
 var name="fore" if gun=="rifle" else "support"
 if gun=="pistol":thumb_weight=0.0
 m.reset(gun);write(gun,m.hold(gun,name),m.holds[gun][name].pose,false)
func update(gun:String,time:float,empty:bool,root_rotation:Quaternion=Quaternion.IDENTITY)->void:
 if not shared_magazine:
  m.root_rotations[gun]=root_rotation;m.update(gun,time)
 if gun=="rifle":rifle(time,empty)
 else:
  pistol(time)
  thumb_weight=Math.ease(m.phase(time,1.37,1.52))*(1-Math.ease(m.phase(time,1.63,1.77))) if empty else 0.0
func rifle(t:float,empty:bool)->void:
 var h=m.holds.rifle
 var rest=m.pose(Vector3(0,-.02,-.0665));var fore=m.hold("rifle","fore")
 var pinch=rest*m.hold("rifle","pinch");var carry=m.hold("rifle","carry")
 var turn=m.euler(-.5,0,.25)
 var away=m.pose(pinch.origin+Vector3(-.06,-.36,.13),turn*pinch.basis.get_rotation_quaternion())
 var rise=m.pose(rest.origin+Vector3(-.05,-.38,.14),turn)*carry
 var relaxed=mix_pose(poses.relaxed,poses.open,.25)
 var loose=mix_pose(poses.pinch,h.pinch.pose,.25)
 var tr:Transform3D
 var fingers:PackedFloat32Array
 if t<.4:
  var approach=m.pose(pinch.origin+Vector3(-.045,-.035,.015),pinch.basis.get_rotation_quaternion())
  tr=m.sample([[0,fore],[.07,fore],[.27,approach],[.36,pinch],[9,pinch]],t)
  fingers=three_pose(h.fore.pose,relaxed,loose,m.phase(t,.03,.3))
  if t>.3:fingers=mix_pose(loose,h.pinch.pose,Math.ease(m.phase(t,.3,.38)))
 elif t<.74:
  var clear=m.out_quad(m.phase(t,.4,.52));var weight=Math.ease(m.phase(t,.49,.74))
  tr=m.pose(pinch.origin.lerp(pinch.origin+Vector3(0,-.082,0),clear).lerp(away.origin,weight),pinch.basis.get_rotation_quaternion().slerp(away.basis.get_rotation_quaternion(),weight))
  fingers=PackedFloat32Array(h.pinch.pose)
 elif t<.86:
  var weight=Math.ease(m.phase(t,.74,.86));tr=m.blend(away,rise,weight)
  fingers=mix_pose(h.pinch.pose,h.carry.pose,weight)
 else:
  var offset=0.0;var cup_weight=0.0
  if t>=1.31 and t<1.385:
   cup_weight=Math.ease(m.phase(t,1.31,1.385));offset=.032*cup_weight
  elif t>=1.385 and t<1.44:
   var phase=m.phase(t,1.385,1.44);var distance=(.009+.032)*(1-phase*phase)
   offset=distance-minf(.009,distance);cup_weight=1
  elif t>=1.44 and t<1.5:offset=.008*m.out_quad(m.phase(t,1.44,1.5));cup_weight=1
  elif t>=1.5 and t<1.54:
   cup_weight=1-Math.ease(m.phase(t,1.5,1.54));offset=.008*cup_weight
  elif t>=1.54 and t<1.6:offset=.005*Math.ease(m.phase(t,1.54,1.6))
  elif t>=1.6 and t<1.66:offset=.005*(1-Math.ease(m.phase(t,1.6,1.66)))
  var release=2.12 if empty else 1.905
  if t<1.66:
   tr=m.poses.rifle*carry;tr.origin.y-=offset
   fingers=mix_pose(h.carry.pose,h.cup.pose,cup_weight)
  elif t<1.84:
   var phase=m.phase(t,1.66,1.84);var weight=Math.ease(phase)
   tr=m.blend(rest*carry,m.hold("rifle","handle"),weight);tr.origin.x-=.03*sin(PI*weight)
   fingers=three_pose(h.carry.pose,relaxed,h.handle.pose,phase)
  elif t<release+.03:
   var back=1.96 if empty else 1.89;var amount=1.0 if empty else .32
   var slide=amount*Math.ease(m.phase(t,1.84,back)) if t<back else amount
   tr=m.hold("rifle","handle");tr.origin.z+=.062*slide
   release_pose=tr
   fingers=mix_pose(h.handle.pose,relaxed,.5*Math.ease(m.phase(t,release,release+.03)))
  else:
   var duration=2.72 if empty else 2.24;var finish=duration-(.1 if empty else .04)
   tr=m.sample([[release+.03,release_pose],[finish,fore],[9,fore]],t)
   var phase=m.phase(t,release+.03,finish);tr.origin.y-=.035*sin(PI*Math.ease(phase))
   fingers=mix_pose(h.handle.pose,relaxed,.5+.5*Math.ease(phase/.6)) if phase<.6 else mix_pose(relaxed,h.fore.pose,Math.ease((phase-.6)/.4))
 write("rifle",tr,fingers)
func pistol(t:float)->void:
 var h=m.holds.pistol;var support=m.hold("pistol","support");var carry=m.hold("pistol","carry");var slap=m.hold("pistol","slap")
 var axis=Vector3(0,-.951,.309);var rake=m.euler(-.314,0,0);var base=Vector3(0,-.013,.0387)
 var risen=m.pose(base+Vector3(.1,-.38,.12),m.euler(-.3,0,.45)*rake)*carry
 var rebound=m.pose(base+axis*.01,rake)*slap
 var relaxed=mix_pose(poses.relaxed,poses.open,.25)
 var tr:Transform3D;var fingers:PackedFloat32Array
 if t<.48:
  tr=m.sample([[0,support],[.05,support],[.42,risen],[9,risen]],t)
  fingers=three_pose(h.support.pose,relaxed,h.carry.pose,m.phase(t,.03,.46))
 elif t<1.19:
  var weight=0.0;var offset=0.0
  if t>=1.02 and t<1.075:weight=Math.ease(m.phase(t,1.02,1.075));offset=.026*weight
  elif t>=1.075 and t<1.13:
   var phase=m.phase(t,1.075,1.13);var distance=(.118-.062+.026)*(1-phase*phase)
   weight=1;offset=distance-minf(.118-.062,distance)
  elif t>=1.13:weight=1;offset=.01*m.out_quad(m.phase(t,1.13,1.19))
  tr=m.blend(m.poses.pistol*carry,m.poses.pistol*slap,weight);tr.origin+=axis*offset
  fingers=mix_pose(h.carry.pose,h.slap.pose,weight)
 else:
  var phase=m.phase(t,1.19,1.44);var weight=Math.ease(phase);var inv=1-weight
  var control=rebound.origin.lerp(support.origin,.5)+Vector3(.035,-.07,.045)
  tr=m.pose(rebound.origin*(inv*inv)+control*(2*inv*weight)+support.origin*(weight*weight),rebound.basis.get_rotation_quaternion().slerp(support.basis.get_rotation_quaternion(),Math.ease(m.phase(t,1.21,1.42))))
  fingers=mix_pose(h.slap.pose,h.supportOpen,Math.ease(phase/.55)) if phase<.55 else mix_pose(h.supportOpen,h.support.pose,Math.ease((phase-.55)/.45))
 write("pistol",tr,fingers)
