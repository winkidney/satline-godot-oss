extends RefCounted
# Original Fh finger/impulse/update around the separately verified L solver.
var math
var config:Dictionary
var pose=PackedFloat32Array()
var shown=PackedFloat32Array()
var spring=PackedFloat32Array([0,0,0,0,0])
var velocity=PackedFloat32Array([0,0,0,0,0])
var trigger=0.0
var bones=[]
var rest_rotations=[]
var rest_positions=[]
var inertia={"x":0.0,"y":0.0,"vx":0.0,"vy":0.0}
var delta=[0.0,0.0,0.0]
var twist_base=[0.0,0.0,0.0,1.0]
var diagnostics={}
func _init(source_config:Dictionary,left:bool=false)->void:
 config=source_config;math=preload("res://scripts/weapon_arm_ik.gd").new(left)
 for j in 35:bones.append({"p":[0.0,0.0,0.0],"q":[0.0,0.0,0.0,1.0]})
 bones[0].p=[0.0,0.0,.57];bones[1].p=[0.0,0.0,-.3];bones[2].p=[0.0,0.0,-.09];bones[3].p=[0.0,0.0,-.2];bones[4].p=[0.0,0.0,-.27]
 for digit in 5:
  for segment in 3:
   var d=config.digits[digit]
   var p=[0.0,0.0,-d.len[segment-1]] if segment>0 else [d.base[0]*math.side,d.base[1],d.base[2]]
   rest_positions.append(p);bones[5+digit*3+segment].p=p.duplicate();bones[20+digit*3+segment].p=p.duplicate()
   rest_rotations.append(finger_rotation(digit,segment,config.rest))
 pose=PackedFloat32Array(config.rest);render_fingers()
func axis(axis_value:Array,angle:float)->Array:
 var t=sin(angle/2)
 return [axis_value[0]*t,axis_value[1]*t,axis_value[2]*t,cos(angle/2)]
func normalize_q(q:Array)->Array:
 var length=sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3])
 return [q[0]/length,q[1]/length,q[2]/length,q[3]/length] if length!=0 else [0.0,0.0,0.0,1.0]
func slerp(a:Array,b:Array,t:float)->Array:
 var dot=a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3];var target=b.duplicate()
 if dot<0:
  dot=-dot
  for j in 4:target[j]=-target[j]
 if dot>=1:return a.duplicate()
 var square=1-dot*dot
 var first=1-t;var second=t
 if square>2.220446049250313e-16:
  var sine=sqrt(square);var angle=atan2(sine,dot)
  first=sin((1-t)*angle)/sine;second=sin(t*angle)/sine
 var result=[]
 for j in 4:result.append(a[j]*first+target[j]*second)
 return normalize_q(result) if square<=2.220446049250313e-16 else result
func rotate(v:Array,q:Array)->Array:
 # Three Vector3.applyQuaternion uses q*v*q^-1 for a unit quaternion.
 var t=math.scale(math.cross([q[0],q[1],q[2]],v),2)
 return math.add(v,math.add(math.scale(t,q[3]),math.cross([q[0],q[1],q[2]],t)))
func finger_rotation(digit:int,segment:int,values)->Array:
 var d=config.digits[digit];var offset=digit*4
 if segment>0:return axis([1,0,0],-values[offset+segment])
 if digit==0:return math.mul(math.mul(axis(math.unit([.2,0,.98]),values[0]),axis([0,1,0],values[3])),d.q0)
 return math.mul(math.mul(axis([0,1,0],d.yaw+d.sgn*values[offset+3]),d.qRoll),axis([1,0,0],-values[offset]))
func render_fingers()->void:
 shown=pose.duplicate()
 for j in 4:shown[4+j]+=[.04,.22,.16,0][j]*trigger
 for digit in 5:
  var value=spring[digit]
  if value!=0:
   shown[digit*4+1]+=value;shown[digit*4+2]+=value*.6
   if digit>0:shown[digit*4]+=value*.4
 for j in 20:shown[j]=clampf(shown[j],config.min[j],config.max[j])
 for digit in 5:
  for segment in 3:
   var index=digit*3+segment
   var rotation=math.mirror_q(finger_rotation(digit,segment,shown))
   bones[5+index].q=rotation
   var helper=slerp(math.mirror_q(rest_rotations[index]),rotation,.5)
   bones[20+index].q=helper
   var difference=0.0 if digit==0 and segment==0 else shown[digit*4+segment]-config.rest[digit*4+segment]
   var weight=sin(clampf(difference,0,2)*.5)
   var offset=rotate([0.0,[.16,.2,.2][segment]*config.digits[digit].rad[segment]*weight*weight,0.0],helper)
   bones[20+index].p=math.add(rest_positions[index],offset)
func set_fingers(values)->void:
 pose=PackedFloat32Array(values);render_fingers()
func set_trigger(value:float)->void:
 var clamped=clampf(value,0,1)
 if clamped!=trigger:trigger=clamped;render_fingers()
func impulse(amount:float=1.0)->void:
 for j in 5:velocity[j]+=amount*(1.6+.3*j)
 inertia.vx+=amount*.5;inertia.vy-=amount*.35
func solve(shoulder,hand,rotation,pole=null,lean:float=0.0)->Dictionary:
 diagnostics=math.solve(shoulder,hand,rotation,pole,lean)
 bones[0].p=diagnostics.shoulder.duplicate()
 for j in 5:bones[j].q=diagnostics.rotations[j].duplicate()
 twist_base=diagnostics.rotations[2].duplicate();delta=diagnostics.displacement.duplicate()
 return diagnostics
func update(dt:float)->void:
 if not dt>0:return
 dt=minf(dt,.05)
 var active=false
 for j in 5:
  velocity[j]+=(-spring[j]*900-velocity[j]*34)*dt
  spring[j]+=velocity[j]*dt
  if absf(spring[j])>2e-4 or absf(velocity[j])>.02:active=true
  else:spring[j]=0;velocity[j]=0
 if active:render_fingers()
 inertia.vx+=(-inertia.x*260-inertia.vx*18)*dt-delta[1]*9
 inertia.vy+=(-inertia.y*260-inertia.vy*18)*dt+delta[0]*9*math.side
 delta=[0.0,0.0,0.0]
 inertia.x+=inertia.vx*dt;inertia.y+=inertia.vy*dt
 var x=clampf(inertia.x,-.06,.06);var y=clampf(inertia.y,-.06,.06)
 bones[2].q=math.mul(twist_base,normalize_q([x*.5,y*.5,0.0,1.0])) if absf(x)>1e-5 or absf(y)>1e-5 else twist_base.duplicate()
