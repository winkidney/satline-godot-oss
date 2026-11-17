extends RefCounted
# Original vS normal target-space/history stage. Fh solve is a separate consumer.
const Math=preload("res://scripts/weapon_motion_math.gd")
var history=[]
var progress=1.0
var duration=0.0
var initialized=false
var pending_local=false
var attached=false
var attachment_p=Vector3.ZERO
var attachment_inverse=Quaternion.IDENTITY
var output={}
var drop_time=-1.0
var group_visible={"r":true,"l":true}
var visible=true
func _init()->void:
 for side in [1,-1]:
  var initial={"p":Vector3.ZERO,"q":Quaternion.IDENTITY,"pose":PackedFloat32Array(),"pole":Vector3(.8*side,-.6,0),"sh":Vector3(.19*side,-.24,.1)}
  initial.pose.resize(20)
  history.append({"last":initial.duplicate(true),"from":initial.duplicate(true),"from_local_p":Vector3.ZERO,"from_local_q":Quaternion.IDENTITY})
func blend(seconds:float=.2)->void:
 if not initialized:return
 for item in history:item.from=item.last.duplicate(true)
 progress=0.0;duration=seconds;pending_local=true
func snap()->void:
 progress=1.0;duration=0.0;pending_local=false
func attach(offset:Dictionary={})->void:
 attached=not offset.is_empty()
 if attached:
  attachment_p=offset.p
  attachment_inverse=offset.q.inverse()
 progress=1.0
func pose_mix(a,b,t:float)->PackedFloat32Array:
 var result=PackedFloat32Array();result.resize(20)
 for j in 20:result[j]=a[j]+(b[j]-a[j])*t
 return result
func update(dt:float,targets:Dictionary,root:Dictionary)->Dictionary:
 if drop_time>=0:return output
 var weight=1.0
 if progress<1 and duration>0:
  progress+=dt/duration;weight=Math.ease(progress)
 if weight>=1:progress=1.0
 if pending_local:
  pending_local=false
  for item in history:
   item.from_local_p=root.q.inverse()*(item.from.p-root.p)
   item.from_local_q=root.q.inverse()*item.from.q
 if weight<1:
  for item in history:
   item.from.p=root.q*item.from_local_p+root.p
   item.from.q=root.q*item.from_local_q
 for j in 2:
  var side="r" if j==0 else "l"
  var target=targets[side];var item=history[j]
  var p:Vector3=target.p if attached else root.q*target.p+root.p
  var q:Quaternion=target.q if attached else root.q*target.q
  var pole:Vector3=attachment_inverse*target.pole if attached else target.pole
  var shoulder:Vector3=attachment_inverse*(target.sh-attachment_p) if attached else target.sh
  var fingers=PackedFloat32Array(target.pose)
  if weight<1:
   p=item.from.p.lerp(p,weight)
   # Original c.slerpQuaternions(from.q,c,w) aliases its destination/second input.
   # Three copies from.q into c before slerp, so orientation stays at from.q.
   q=item.from.q
   pole=item.from.pole.lerp(pole,weight);shoulder=item.from.sh.lerp(shoulder,weight)
   fingers=pose_mix(item.from.pose,target.pose,weight)
  item.last={"p":p,"q":q,"pole":pole,"sh":shoulder,"pose":fingers}
  output[side]=item.last.duplicate(true)
  output[side].trig=target.trig
  output[side].lean=.2
 initialized=true
 return output

func start_drop(random:Callable)->void:
 if not initialized:return
 drop_time=0.0;progress=1.0
 for j in 2:
  var item=history[j];var side=1.0 if j==0 else -1.0
  item.from.p=item.last.p;item.from.q=item.last.q;item.from.pose=item.last.pose.duplicate()
  item.velocity=Vector3(side*(.1+random.call()*.08),-.05,.1)
  item.angular=Vector3(-1.5-random.call()*.5,side*.5,side*(.7+random.call()*.4))
func drop_update(dt:float,relaxed)->Dictionary:
 var changed={}
 if drop_time<0:return changed
 drop_time+=dt
 var weight=Math.ease(drop_time/.15)
 for j in 2:
  var side="r" if j==0 else "l"
  if not group_visible[side]:continue
  var item=history[j]
  item.velocity.y-=2.2*dt;item.from.p+=item.velocity*dt
  var angle=item.angular.length()*dt
  if angle>0:item.from.q=item.from.q*Quaternion(item.angular.normalized(),angle)
  var target={"p":item.from.p,"q":item.from.q,"pose":pose_mix(item.from.pose,relaxed,weight),"trig":0.0,"sh":item.last.sh,"pole":item.last.pole,"lean":.2}
  output[side]=target;changed[side]=target
  item.last.p=item.from.p;item.last.q=item.from.q
  if drop_time>.9 or item.from.p.y<-.6:group_visible[side]=false
 return changed
func restore()->void:
 if drop_time<0:return
 drop_time=-1.0;progress=1.0;initialized=false
 for side in ["r","l"]:group_visible[side]=visible
