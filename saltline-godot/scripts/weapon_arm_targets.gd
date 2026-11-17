extends RefCounted
# Source armTargets only. Reload left-hand targets and IK are supplied separately.
var holds:Dictionary
var config:Dictionary
var engagement={"rifle":1.0,"pistol":1.0}
func _init(rigs:Dictionary,source_config:Dictionary)->void:
 config=source_config
 holds={"rifle":rigs.rifle.holds,"pistol":rigs.pistol.holds}
func smooth(value:float)->float:
 var x=clampf(value,0.0,1.0)
 return x*x*x*(x*(6*x-15)+10)
func vec(a)->Vector3:return Vector3(a[0],a[1],a[2])
func target_weight(state:Dictionary)->float:
 return 0.0 if state.spV.x>.3 or state.reload!=null or state.hol>.12 else 1.0
func snap(gun:String,state:Dictionary)->void:engagement[gun]=target_weight(state)
func reset()->void:
 engagement={"rifle":1.0,"pistol":1.0}
func update(gun:String,dt:float,state:Dictionary,finger:float,left:Dictionary={},stop_weight:float=0.0)->Dictionary:
 var h=holds[gun];var c=config[gun]
 var weight:float=engagement[gun]
 weight+=(target_weight(state)-weight)*(1-exp(-16*dt))
 engagement[gun]=weight
 var pose=PackedFloat32Array();pose.resize(20)
 var t=smooth(weight)
 for j in 20:pose[j]=h.grip.pose[j]+(h.trigger.pose[j]-h.grip.pose[j])*t
 var right={"p":vec(h.grip.p),"q":Quaternion(h.grip.q[0],h.grip.q[1],h.grip.q[2],h.grip.q[3]),"pose":pose,"trig":finger*weight,"pole":vec(c.poleR),"sh":vec(c.shR)}
 var sprint=clampf(state.spV.x,0,1)
 right.pole=right.pole.lerp(vec(c.sprintPoleR),sprint)
 right.sh=right.sh.lerp(vec(c.sprintShR),sprint)
 var rest=h.fore if gun=="rifle" else h.support
 var left_target={"p":vec(left.get("p",rest.p)),"q":left.get("q",Quaternion(rest.q[0],rest.q[1],rest.q[2],rest.q[3])),"pose":PackedFloat32Array(left.pose if left.get("busy",false) else rest.pose),"trig":0.0,"pole":vec(c.poleL),"sh":vec(c.shL)}
 if gun=="pistol":
  var ads=smooth(clampf(state.adsV.x,0,1))
  right.pole=right.pole.lerp(vec(c.ads.poleR),ads)
  right.sh=right.sh.lerp(vec(c.ads.shR),ads)
  left_target.pole=left_target.pole.lerp(vec(c.ads.poleL),ads)
  left_target.sh=left_target.sh.lerp(vec(c.ads.shL),ads)
  if stop_weight>0:
   for j in 4:right.pose[j]+=(h.stop.pose[j]-right.pose[j])*stop_weight
 return {"r":right,"l":left_target}
