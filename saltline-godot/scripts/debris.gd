class_name SaltlineDebris
extends RefCounted

var mesh:MultiMeshInstance3D
var slots:Array=[]
var next=0
var live=0
var emitted=0
var bounces=0
var settled=0
var rng=preload("res://scripts/fx_random.gd").new()
var transforms:Array[Transform3D]=[]

func _init(scene:SaltlineSourceScene,random_stream=null)->void:
 if random_stream!=null:rng=random_stream
 for record in scene.source.nodes:
  if record.name=="fx_debris":mesh=scene.source_nodes[record.id];break
 assert(mesh!=null)
 for i in mesh.multimesh.instance_count:
  slots.append({"state":0});transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

func _set_transform(index:int,transform:Transform3D)->void:
 transforms[index]=transform;mesh.multimesh.set_instance_transform(index,transform)

func f32(value:float)->float:
 return PackedFloat32Array([value])[0]

func emit(position:Vector3,velocity:Vector3,size:Vector3,color:Vector3,life:float,floor_y:float)->void:
 var axis=Vector3(rng.randf()-.5,rng.randf()-.5,rng.randf()-.5).normalized()
 slots[next]={"state":1,"position":position,"velocity":velocity,"axis":axis,"angle":f32(rng.randf()*6.28),"spin":f32((rng.randf()-.5)*50),"size":size,"color":color,"age":0.0,"life":f32(life),"floor":f32(floor_y)}
 var tint:Vector3=slots[next].color
 mesh.multimesh.set_instance_custom_data(next,Color(tint.x,tint.y,tint.z,1))
 next=(next+1)%slots.size();emitted+=1

func update(dt:float)->void:
 live=0
 for index in slots.size():
  var slot:Dictionary=slots[index]
  if slot.state==0:continue
  slot.age=f32(slot.age+dt)
  var remaining=slot.life-slot.age
  if remaining<=0:
   slot.state=0;_set_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO));continue
  live+=1
  if slot.state==2 and remaining>.5:continue
  if slot.state==1:
   slot.velocity.y-=9.81*dt;slot.position+=slot.velocity*dt;slot.angle=f32(slot.angle+slot.spin*dt)
   var support=slot.floor+minf(slot.size.x,minf(slot.size.y,slot.size.z))*.5
   if slot.position.y<support and slot.velocity.y<0:
    slot.position.y=support;bounces+=1
    if slot.velocity.y> -1.2:slot.state=2;slot.velocity=Vector3.ZERO;settled+=1
    else:
     slot.velocity.y=-slot.velocity.y*.32;slot.velocity.x*=.55;slot.velocity.z*=.55;slot.spin=f32(slot.spin*.5)
  var shrink=remaining/.5 if remaining<.5 else 1.0
  var basis=Basis(Quaternion(slot.axis,slot.angle))
  basis.x*=slot.size.x*shrink;basis.y*=slot.size.y*shrink;basis.z*=slot.size.z*shrink
  _set_transform(index,Transform3D(basis,slot.position))
 mesh.visible=live>0

func clear()->void:
 for index in slots.size():slots[index]={"state":0};_set_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
 live=0;mesh.visible=false
