class_name SaltlineExplosives
extends RefCounted

var combat:SaltlineCombat

signal blasted(position:Vector3,kind:String)
var scene:SaltlineSourceScene
var physics:SaltlinePhysics
var effects:SaltlineExplosionEffects
var player:SaltlinePlayer
var items:Array=[]
var rng:SaltlineSourceRng
var blasts=0

func _init(source_scene:SaltlineSourceScene,collision:SaltlinePhysics,explosion_fx:SaltlineExplosionEffects,avatar:SaltlinePlayer,random_stream:SaltlineSourceRng=null)->void:
 scene=source_scene;physics=collision;effects=explosion_fx;player=avatar;rng=random_stream if random_stream!=null else preload("res://scripts/source_bootstrap.gd").new().streams.explosives
 for entry in scene.source.modules.explosives.items:
  var item:Dictionary=entry.duplicate(true)
  for key in ["min","max","pos","leak","leakDir"]:
   var value:Array=entry[key];item[key]=Vector3(value[0],value[1],value[2])
  item.box={}
  items.append(item);_bind_box(items.size()-1)
 effects.exploded.connect(_chain)

func _bind_box(index:int)->void:
 var item:Dictionary=items[index]
 for box in physics.boxes:
  if box.tag=="explosive" and box.min.distance_to(item.min)<.0001 and box.max.distance_to(item.max)<.0001:
   box.explosive_index=index;item.box=box;return
 var box={"min":item.min,"max":item.max,"surface":"metal","tag":"explosive","noNav":false,"bulletOnly":false,"playerOnly":false,"explosive_index":index}
 physics.boxes.append(box);item.box=box
 if scene.is_inside_tree():
  var body=StaticBody3D.new();var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=(item.max-item.min).max(Vector3.ONE*.001)
  collision.shape=shape;body.position=(item.max+item.min)*.5;body.add_child(collision);scene.add_child(body);box.body=body

func _visible(item:Dictionary,visible:bool)->void:
 if item.inst is Array:
  for binding in item.inst:
   var node:MultiMeshInstance3D=scene.source_nodes[binding.im["$node"]]
   node.multimesh.set_instance_transform(int(binding.i),scene._transform(binding.m) if visible else Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
 else:
  var node:Node3D=scene.source_nodes.get(item.obj["$node"])
  if node:node.visible=visible

func impact(hit:Dictionary,damage:float)->void:
 if hit.is_empty() or not hit.get("box") is Dictionary:return
 var box:Dictionary=hit.box
 if box.has("explosive_index"):damage_item(int(box.explosive_index),damage,hit.point)

func damage_item(index:int,damage:float,point:Variant=null)->void:
 var item:Dictionary=items[index]
 if not item.alive:return
 item.hp-=damage
 if item.hp<=0:
  item.fuse=.06 if item.fuse<0 else minf(item.fuse,.06);return
 if item.fuse<0:
  item.fuse=item.spec.fuse
  if point is Vector3:
   item.leak=point;item.leakDir=Vector3(point.x-item.pos.x,.35,point.z-item.pos.z).normalized()
  else:item.leak=Vector3(item.pos.x,item.max.y,item.pos.z);item.leakDir=Vector3.UP

func _chain(position:Vector3,size:float)->void:
 var radius=2.2+(size if size!=0 else 1.0)*1.6
 for item in items:
  if not item.alive:continue
  var distance=item.pos.distance_to(position)
  if distance>radius or distance<.05:continue
  var delay=.14+rng.randf()*.3+distance*.03
  item.fuse=delay if item.fuse<0 else minf(item.fuse,delay)

func _blast(item:Dictionary)->void:
 item.alive=false;item.fuse=-1;_visible(item,false)
 if not item.box.is_empty():
  if is_instance_valid(item.box.get("body")):item.box.body.queue_free()
  physics.boxes.erase(item.box);item.box={}
 blasts+=1;effects.explode(item.pos,item.spec.size)
 var color=Color.hex(0x3a0f0aff if item.kind=="barrel" else 0x30343aff).srgb_to_linear()
 effects.fx.fragments(item.pos,Vector3.UP,14,3.6,11.7,Vector3(.036,.027,.036),Vector3(.108,.081,.108),Vector3(color.r,color.g,color.b),1.4)
 if combat!=null:combat.explode(item.pos,item.spec.radius,item.spec.damage,"explosive")
 else:
  var target=player.pos+Vector3.UP;var distance=target.distance_to(item.pos)
  if player.alive and distance<item.spec.radius and physics.line_of_sight(item.pos,target):player.damage(item.spec.damage*.5*(1-distance/item.spec.radius),item.pos)
 var strength=maxf(0,1-player.pos.distance_to(item.pos)/28)
 if strength>0:player.shake=minf(1,player.shake+.15+.9*strength*strength)
 blasted.emit(item.pos,item.kind)

func update(dt:float)->void:
 for item in items:
  if not item.alive or item.fuse<0:continue
  item.fuse-=dt
  if item.fuse<=0:_blast(item);continue
  item.tick-=dt
  if item.tick<=0:
   item.tick=.07
   effects.fx.sparks(item.leak,item.leakDir,3)
   effects.fx.smoke(item.leak,{"size":.3,"life":.9,"rise":1.4,"count":1,"color":0x151515,"vel":item.leakDir*1.5})
   effects.lights.flash(item.leak,0xff7a20,5,4,.09)

func reset()->void:
 for index in items.size():
  var item:Dictionary=items[index];item.alive=true;item.hp=item.spec.hp;item.fuse=-1;_visible(item,true)
  if item.box.is_empty():_bind_box(index)

func alive_count()->int:
 var count=0
 for item in items:
  if item.alive:count+=1
 return count
