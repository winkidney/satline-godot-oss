extends RefCounted
# Original Fh.L two-bone/wrist solve. Arrays keep JS double math until bone writes.
var side=1.0
var previous=[]
var displacement=[0.0,0.0,0.0]
func _init(left:bool=false)->void:side=-1.0 if left else 1.0
func add(a,b)->Array:return [a[0]+b[0],a[1]+b[1],a[2]+b[2]]
func sub(a,b)->Array:return [a[0]-b[0],a[1]-b[1],a[2]-b[2]]
func scale(a,t:float)->Array:return [a[0]*t,a[1]*t,a[2]*t]
func dot(a,b)->float:return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
func length(a)->float:return sqrt(dot(a,a))
func unit(a)->Array:
 var size=length(a)
 return scale(a,1.0/size) if size!=0 else [0.0,0.0,0.0]
func cross(a,b)->Array:return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
func mul(a,b)->Array:
 return [a[0]*b[3]+a[3]*b[0]+a[1]*b[2]-a[2]*b[1],a[1]*b[3]+a[3]*b[1]+a[2]*b[0]-a[0]*b[2],a[2]*b[3]+a[3]*b[2]+a[0]*b[1]-a[1]*b[0],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]]
func inverse(q)->Array:return [-q[0],-q[1],-q[2],q[3]]
func mirror_q(q)->Array:return [q[0],q[1]*side,q[2]*side,q[3]]
func mirror_p(p)->Array:return [p[0]*side,p[1],p[2]]
func axis_z(angle:float)->Array:return [0.0,0.0,sin(angle/2),cos(angle/2)]
func basis_quat(x,y,z)->Array:
 var m11=x[0];var m12=y[0];var m13=z[0];var m21=x[1];var m22=y[1];var m23=z[1];var m31=x[2];var m32=y[2];var m33=z[2]
 var trace=m11+m22+m33
 var s:float
 if trace>0:
  s=.5/sqrt(trace+1.0)
  return [(m32-m23)*s,(m13-m31)*s,(m21-m12)*s,.25/s]
 if m11>m22 and m11>m33:
  s=2*sqrt(1+m11-m22-m33)
  return [.25*s,(m12+m21)/s,(m13+m31)/s,(m32-m23)/s]
 if m22>m33:
  s=2*sqrt(1+m22-m11-m33)
  return [(m12+m21)/s,.25*s,(m23+m32)/s,(m13-m31)/s]
 s=2*sqrt(1+m33-m11-m22)
 return [(m13+m31)/s,(m23+m32)/s,.25*s,(m21-m12)/s]
func solve(shoulder,hand,rotation,pole=null,lean:float=0.0)->Dictionary:
 var sh=mirror_p(shoulder);var wrist=mirror_p(hand);var desired=mirror_q(rotation)
 var bend=mirror_p(pole) if pole!=null else [.8,-.6,0.0]
 var direction=sub(wrist,sh);var distance=length(direction)
 if distance==0:distance=1e-6
 direction=scale(direction,1.0/distance)
 var maximum=(.3+.27)*.999;var minimum=absf(.3-.27)+.02;var leaned=0.0
 if distance>maximum and lean>0:
  leaned=minf(lean,distance-maximum);sh=add(sh,scale(direction,leaned));distance-=leaned
 var reach=maxf(0,distance-maximum)
 if reach>0:distance=maximum;wrist=add(sh,scale(direction,distance))
 elif distance<minimum:distance=minimum;wrist=add(sh,scale(direction,distance))
 var axial=(distance*distance+.3*.3-.27*.27)/(2*distance)
 var height=sqrt(maxf(0,.3*.3-axial*axial))
 bend=add(bend,scale(direction,-dot(bend,direction)))
 if dot(bend,bend)<1e-8:
  bend=add([0.0,-1.0,0.0],scale(direction,direction[1]))
  if dot(bend,bend)<1e-8:bend=add([1.0,0.0,0.0],scale(direction,-direction[0]))
 bend=unit(bend)
 var elbow=add(add(sh,scale(direction,axial)),scale(bend,height))
 var right=unit(cross(bend,direction))
 var upper_z=unit(sub(sh,elbow));var upper=basis_quat(right,cross(upper_z,right),upper_z)
 var fore_z=unit(sub(elbow,wrist));var fore=basis_quat(right,cross(fore_z,right),fore_z)
 var relative=mul(inverse(fore),desired)
 if relative[3]<0:
  for j in 4:relative[j]=-relative[j]
 var twist=2*atan2(relative[2],relative[3])
 while twist>PI/2:twist-=2*PI
 while twist<=-1.5*PI:twist+=2*PI
 var swing=mul(axis_z(-twist),relative)
 if swing[3]<0:
  for j in 4:swing[j]=-swing[j]
 var size=sqrt(swing[0]*swing[0]+swing[1]*swing[1]+swing[2]*swing[2])
 var angle=2*atan2(size,swing[3]);var factor=angle/size if size>1e-9 else 2.0
 var flex=-swing[0]*factor;var deviation=swing[1]*factor;var offset_twist=twist+PI/2
 var violation=maxf(0,maxf(maxf(-1.22-flex,flex-1.4),maxf(maxf(-.61-deviation,deviation-.35),maxf(-1.66-offset_twist,offset_twist-1.66))))
 var final_hand=mirror_p(wrist)
 if not previous.is_empty():displacement=sub(final_hand,previous)
 previous=final_hand
 return {"reach":reach,"lean":leaned,"wristFlex":flex,"wristDeviation":deviation,"twist":offset_twist,"violation":violation,"elbow":mirror_p(elbow),"shoulder":mirror_p(sh),"hand":final_hand,"rotations":[mirror_q(upper),mirror_q(mul(inverse(upper),fore)),mirror_q(axis_z(twist*.42)),mirror_q(axis_z(twist*.84)),mirror_q(relative)],"displacement":displacement.duplicate()}
