class_name SaltlineTracers
extends Node3D

const CAPACITY=48
var shots:Array=[]
var rng=preload("res://scripts/fx_random.gd").new()
var geometry:MeshInstance3D
var material:ShaderMaterial
var camera:Camera3D
var emitted=0
var quads_drawn=0
var draw_records:Array=[]

func setup(scene:SaltlineSourceScene,view:Camera3D,lit:bool=false,random_stream=null)->void:
 camera=view
 if random_stream!=null:rng=random_stream
 var record:Dictionary
 for entry in scene.source.materials:
  if entry.name==("fx_lit" if lit else "fx_add"):record=entry;break
 material=ShaderMaterial.new();material.shader=load("res://shaders/lit_particle.gdshader" if lit else "res://shaders/additive_particle.gdshader")
 material.set_shader_parameter("atlas_tex",scene._texture(record.uniforms.uTex.value))
 material.render_priority=10 if lit else 20
 if lit:
  for parameter in ["uSun","uSunDir","uAmbLo","uAmbHi"]:
   var value:Array=record.uniforms[parameter].value;material.set_shader_parameter(parameter,Vector3(value[0],value[1],value[2]))
 geometry=MeshInstance3D.new();geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;geometry.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3(2000,2000,2000));add_child(geometry)

func f32(value:float)->float:return PackedFloat32Array([value])[0]

func emit(origin:Vector3,end:Vector3,color:Vector3=Vector3(16,12.8,7.36),speed:float=260,width:float=.024)->void:
 var dx=float(end.x)-origin.x;var dy=float(end.y)-origin.y;var dz=float(end.z)-origin.z
 var distance=sqrt(dx*dx+dy*dy+dz*dz)
 if distance<.001:return
 var shot={"origin":origin,"direction":Vector3(dx/distance,dy/distance,dz/distance),"distance":f32(distance),"speed":f32(speed),"travel":0.0,"length":f32(minf(maxf(speed*.022,2),7)),"width":f32(width),"color":color,"frames":0}
 if shots.size()>=CAPACITY:shots[0]=shot
 else:shots.append(shot)
 emitted+=1

func update(dt:float)->void:
 var quads=[]
 var index=0
 while index<shots.size():
  var shot:Dictionary=shots[index]
  if shot.frames==0:shot.travel=f32(minf(shot.distance,shot.speed*maxf(dt,.008)*(.35+rng.randf()*.4)))
  else:shot.travel=f32(shot.travel+shot.speed*dt)
  var head=minf(shot.travel,shot.distance)
  var tail=maxf(0,shot.travel-shot.length)
  if tail>=shot.distance:
   if shot.frames>=2:
    shots[index]=shots[-1];shots.pop_back();continue
   tail=maxf(0,shot.distance-shot.length*.5);head=shot.distance
  shot.frames=mini(250,shot.frames+1)
  var middle=(head+tail)*.5;var span=maxf(head-tail,.05)
  var d:Vector3=shot.direction;var o:Vector3=shot.origin;var c:Vector3=shot.color
  var center=Vector3(o.x+d.x*middle,o.y+d.y*middle,o.z+d.z*middle)
  var axis=Vector3(d.x*span,d.y*span,d.z*span)
  quads.append([center,shot.width,axis,c,7,1,5])
  quads.append([center,shot.width*6,Vector3(d.x*span*1.05,d.y*span*1.05,d.z*span*1.05),Vector3(c.x*.04,c.y*.032,c.z*.028),7,1,28])
  quads.append([Vector3(o.x+d.x*head,o.y+d.y*head,o.z+d.z*head),shot.width*5,Vector3.UP,Vector3(c.x*.2,c.y*.16,c.z*.12),0,0,1])
  index+=1
 _draw(quads)

func _draw(quads:Array)->void:
 draw_records=quads
 quads_drawn=quads.size();geometry.visible=not quads.is_empty()
 if quads.is_empty():return
 material.set_shader_parameter("world_pixel_size",2*tan(deg_to_rad(camera.fov)*.5)/maxf(1,camera.get_viewport().get_visible_rect().size.y))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 var positions=PackedVector3Array();var indices=PackedInt32Array()
 var attributes=[PackedFloat32Array(),PackedFloat32Array(),PackedFloat32Array(),PackedFloat32Array()]
 var corners=[Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(.5,.5,0),Vector3(-.5,.5,0)]
 for q in quads:
  var base=positions.size()
  for corner in corners:
   positions.append(corner)
   attributes[0].append_array(PackedFloat32Array([q[0].x,q[0].y,q[0].z,q[1]]))
   attributes[1].append_array(PackedFloat32Array([q[2].x,q[2].y,q[2].z,q[7] if q.size()>7 else 0]))
   attributes[2].append_array(PackedFloat32Array([q[3].x,q[3].y,q[3].z,q[8] if q.size()>8 else 1]))
   attributes[3].append_array(PackedFloat32Array([q[4],q[5],q[9] if q.size()>9 else 0,q[6]]))
  indices.append_array(PackedInt32Array([base,base+2,base+1,base,base+3,base+2]))
 arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_INDEX]=indices
 var flags=0
 for slot in 4:
  arrays[Mesh.ARRAY_CUSTOM0+slot]=attributes[slot]
  flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<[Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT][slot]
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,material);geometry.mesh=mesh

func draw_source_quads(source_quads:Array)->void:
 var converted=[]
 for q in source_quads:converted.append([Vector3(q[0],q[1],q[2]),q[3],Vector3(q[4],q[5],q[6]),Vector3(q[8],q[9],q[10]),q[12],q[13],q[15],q[7],q[11],q[14]])
 _draw(converted)

func clear()->void:
 shots.clear();draw_records.clear();quads_drawn=0
 if geometry!=null:geometry.visible=false
