class_name SaltlineBolts
extends RefCounted

signal impact(hit:Dictionary)
var tuning:Dictionary
var physics:SaltlinePhysics
var player:Variant
var slots:Array=[]
var geometry:MultiMeshInstance3D
var transforms:Array=[]
var emitted=0
var dropped=0
var player_hits=0
var world_hits=0
var expired=0
var maximum_live=0

func _init(settings:Dictionary,collision:SaltlinePhysics,avatar:Variant)->void:
 tuning=settings;physics=collision;player=avatar
 for i in int(tuning.maxBolts):slots.append({"on":false,"life":0.0,"len":0.0,"pos":Vector3.ZERO,"dir":Vector3.ZERO,"from":Vector3.ZERO})

func setup(scene:SaltlineSourceScene)->void:
 for record in scene.source.nodes:
  if record.get("instanceCapacity",0)==int(tuning.maxBolts) and scene.records.get(record.parent,{}).get("name")=="enemies":
   geometry=scene.source_nodes[record.id];break
 assert(geometry!=null,"Original enemy bolt mesh not found")
 geometry.multimesh.instance_count=int(tuning.maxBolts);geometry.multimesh.visible_instance_count=0
 geometry.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3(2000,2000,2000))

func fire(position:Vector3,direction:Vector3)->bool:
 for slot in slots:
  if slot.on:continue
  slot.on=true;slot.life=1.3;slot.pos=position;slot.dir=direction;slot["from"]=position;slot.len=0;emitted+=1;return true
 dropped+=1;return false

# Original jD segment/segment squared distance, including both degenerate cases.
static func segment_distance_squared(start:Vector3,end:Vector3,axis_start:Vector3,axis_end:Vector3)->float:
 var ray=end-start;var axis=axis_end-axis_start;var offset=start-axis_start
 var ray_length=ray.dot(ray);var axis_length=axis.dot(axis);var axis_offset=axis.dot(offset)
 var along_ray=0.0;var along_axis=0.0
 if ray_length<=1e-9 and axis_length<=1e-9:return offset.dot(offset)
 if ray_length<=1e-9:along_axis=clampf(axis_offset/axis_length,0,1)
 else:
  var ray_offset=ray.dot(offset)
  if axis_length<=1e-9:along_ray=clampf(-ray_offset/ray_length,0,1)
  else:
   var alignment=ray.dot(axis);var denominator=ray_length*axis_length-alignment*alignment
   along_ray=clampf((alignment*axis_offset-ray_offset*axis_length)/denominator,0,1) if denominator>1e-9 else 0.0
   along_axis=(alignment*along_ray+axis_offset)/axis_length
   if along_axis<0:along_axis=0;along_ray=clampf(-ray_offset/ray_length,0,1)
   elif along_axis>1:along_axis=1;along_ray=clampf((alignment-ray_offset)/ray_length,0,1)
 var closest=offset+ray*along_ray-axis*along_axis
 return closest.dot(closest)

func update(dt:float)->void:
 transforms.clear()
 for slot in slots:
  if not slot.on:continue
  var distance=float(tuning.gull.boltSpeed)*dt;slot.life-=dt
  var hit=physics.raycast(slot.pos,slot.dir,distance)
  var limit=float(hit.dist) if not hit.is_empty() else distance
  if player!=null and player.alive:
   var end:Vector3=slot.pos+slot.dir*limit
   var lower:Vector3=player.pos+Vector3(0,.35,0);var upper:Vector3=player.pos+Vector3(0,1 if player.crouching else 1.5,0)
   if segment_distance_squared(slot.pos,end,lower,upper)<.36*.36:
    player.damage(tuning.gull.boltDamage,slot["from"]);slot.on=false;player_hits+=1;continue
  if not hit.is_empty():
   impact.emit({"point":hit.point,"normal":hit.normal,"dist":hit.dist,"surface":hit.surface,"enemy":null,"part":null,"dir":slot.dir,"from":"enemy"})
   slot.on=false;world_hits+=1;continue
  if slot.life<=0:slot.on=false;expired+=1;continue
  slot.pos+=slot.dir*distance;slot.len=minf(1.5,slot.len+distance)
  var rotation=direction_basis(slot.dir);var length=maxf(.2,slot.len)
  rotation.z*=length
  transforms.append(Transform3D(rotation,slot.pos))
 maximum_live=maxi(maximum_live,transforms.size())
 if geometry!=null:
  for i in transforms.size():geometry.multimesh.set_instance_transform(i,transforms[i])
  geometry.multimesh.visible_instance_count=transforms.size()

func clear()->void:
 for slot in slots:slot.on=false
 transforms.clear()
 if geometry!=null:geometry.multimesh.visible_instance_count=0

static func direction_basis(direction:Vector3)->Basis:
 var real=1+float(direction.z)
 var quaternion=Quaternion(0,-1,0,0) if real<1e-8 else Quaternion(-direction.y,direction.x,0,real).normalized()
 return Basis(quaternion)
