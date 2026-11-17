class_name SaltlineShells
extends RefCounted

signal bounced(position:Vector3,surface:String,bounce:int)

var mesh:MultiMeshInstance3D
var physics:SaltlinePhysics
var slots:Array=[]
var next=0
var rng=preload("res://scripts/fx_random.gd").new()
var emitted=0
var bounces=0
var settled=0
# The source shares one Euler across emissions and retains its order after rest.
var euler_order="XYZ"
func f32(value:float)->float:return PackedFloat32Array([value])[0]
func shell_rotation(x:float,y:float,z:float)->Quaternion:
 var c1=cos(x/2);var c2=cos(y/2);var c3=cos(z/2);var s1=sin(x/2);var s2=sin(y/2);var s3=sin(z/2)
 if euler_order=="ZXY":return Quaternion(s1*c2*c3-c1*s2*s3,c1*s2*c3+s1*c2*s3,c1*c2*s3+s1*s2*c3,c1*c2*c3-s1*s2*s3)
 return Quaternion(s1*c2*c3+c1*s2*s3,c1*s2*c3-s1*c2*s3,c1*c2*s3+s1*s2*c3,c1*c2*c3-s1*s2*s3)

func shell_basis(q:Quaternion,size:float)->Basis:
 # Three composes the stored Float32 quaternion without renormalizing it.
 var x=float(q.x);var y=float(q.y);var z=float(q.z);var w=float(q.w)
 var x2=x+x;var y2=y+y;var z2=z+z
 var xx=x*x2;var xy=x*y2;var xz=x*z2;var yy=y*y2;var yz=y*z2;var zz=z*z2
 var wx=w*x2;var wy=w*y2;var wz=w*z2
 return Basis(Vector3((1-(yy+zz))*size,(xy+wz)*size,(xz-wy)*size),Vector3((xy-wz)*size,(1-(xx+zz))*size,(yz+wx)*size),Vector3((xz+wy)*size,(yz-wx)*size,(1-(xx+yy))*size))

func _init(scene:SaltlineSourceScene,collision:SaltlinePhysics,random_stream=null)->void:
 physics=collision
 if random_stream!=null:rng=random_stream
 for record in scene.source.nodes:
  if record.name=="fx_shells":mesh=scene.source_nodes[record.id];break
 assert(mesh!=null)
 mesh.visible=false
 for i in mesh.multimesh.instance_count:slots.append({"state":0})

func _floor_at(slot:Dictionary)->void:
 var hit=physics.raycast(slot.pos+Vector3(0,.25,0),Vector3.DOWN,6)
 slot.floor=f32(hit.point.y if not hit.is_empty() else -50.0)
 slot.surface=hit.surface if not hit.is_empty() else "concrete"

func emit(position:Vector3,velocity:Vector3)->void:
 var slot={"state":1,"pos":position,"vel":velocity,"rotation":shell_rotation(rng.randf()*6.28,rng.randf()*6.28,rng.randf()*6.28),"angular":Vector3((rng.randf()-.5)*40,(rng.randf()-.5)*20,(rng.randf()-.5)*40),"age":0.0,"rest":0.0,"bounces":0}
 _floor_at(slot);slots[next]=slot;next=(next+1)%slots.size();emitted+=1

func update(dt:float)->void:
 var live=0
 for index in slots.size():
  var slot:Dictionary=slots[index]
  if slot.state==0:continue
  live+=1;slot.age=f32(slot.age+dt)
  var size=1.0
  if slot.state==1:
   slot.vel.y=f32(slot.vel.y-9.81*dt)
   slot.pos=Vector3(float(slot.pos.x)+float(slot.vel.x)*dt,float(slot.pos.y)+float(slot.vel.y)*dt,float(slot.pos.z)+float(slot.vel.z)*dt)
   # Original quaternion integration uses angular velocity on the left.
   var q:Quaternion=slot.rotation;var w:Vector3=slot.angular;var h=.5*dt
   var x=float(q.x)+h*(float(w.x)*q.w+float(w.y)*q.z-float(w.z)*q.y)
   var y=float(q.y)+h*(float(w.y)*q.w+float(w.z)*q.x-float(w.x)*q.z)
   var z=float(q.z)+h*(float(w.z)*q.w+float(w.x)*q.y-float(w.y)*q.x)
   var a=float(q.w)-h*(float(w.x)*q.x+float(w.y)*q.y+float(w.z)*q.z)
   var length=sqrt(x*x+y*y+z*z+a*a);var inverse=1.0/(length if length!=0 else 1.0)
   slot.rotation=Quaternion(x*inverse,y*inverse,z*inverse,a*inverse)
   if slot.pos.y<slot.floor+.0065 and slot.vel.y<0:
    slot.pos.y=slot.floor+.0065
    var count:int=slot.bounces;slot.bounces+=1;bounces+=1
    if count<2:bounced.emit(slot.pos,slot.surface,count)
    if slot.vel.y>-.9 or count>=4:
     slot.state=2;slot.vel=Vector3.ZERO;settled+=1
     euler_order="ZXY"
     slot.rotation=shell_rotation(PI/2,0,rng.randf()*6.28)
    else:
     slot.vel.y=f32(-float(slot.vel.y)*(.32+rng.randf()*.16))
     slot.vel.x=f32(float(slot.vel.x)*.6+(rng.randf()-.5)*.6);slot.vel.z=f32(float(slot.vel.z)*.6+(rng.randf()-.5)*.6)
     slot.angular=Vector3((rng.randf()-.5)*50,(rng.randf()-.5)*30,(rng.randf()-.5)*50)
     if count==0:_floor_at(slot)
   if slot.age>8:slot.state=2
  else:
   slot.rest=f32(slot.rest+dt)
   if slot.rest<4 and slot.rest>dt*1.5:continue
   if slot.rest>=4.7:
    slot.state=0;mesh.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO));continue
   if slot.rest>=4:size=1-(slot.rest-4)/.7
  mesh.multimesh.set_instance_transform(index,Transform3D(shell_basis(slot.rotation,size),slot.pos))
 mesh.visible=live>0

func clear()->void:
 for index in slots.size():slots[index]={"state":0};mesh.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
 mesh.visible=false
