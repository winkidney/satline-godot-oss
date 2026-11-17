class_name SaltlineRain
extends RefCounted

signal thunder(intensity:float)
var time=0.0
var level=.6
var target=.6
var thunder_timer=30.0
var rng:SaltlineSourceRng
var scene:SaltlineSourceScene
var rain:MultiMeshInstance3D
var splash:MultiMeshInstance3D
var materials:Array=[]
var boxes_min=PackedVector3Array()
var boxes_max=PackedVector3Array()
var skylights=PackedVector4Array()
var pixel_width=.002
var drip=0.0

func _init(source:SaltlineSourceScene,random_stream:SaltlineSourceRng=null,initial_state:Dictionary={})->void:
 scene=source
 var bootstrap=preload("res://scripts/source_bootstrap.gd").new()
 rng=random_stream if random_stream!=null else bootstrap.streams.rain
 var initial=bootstrap.bootstrap_data.streams.rain.initial_state if initial_state.is_empty() else initial_state
 for record in scene.source.nodes:
  if record.name=="rain":rain=scene.source_nodes[record.id];materials.append(scene.materials[record.materials[0]])
  elif record.name=="rainSplash":splash=scene.source_nodes[record.id];materials.append(scene.materials[record.materials[0]])
 var generated=preload("res://scripts/rain_initialization.gd").generate(rng.seed,float(scene.source.quality.rain))
 for entry in [[rain,generated.rain],[splash,generated.splash]]:
  var mesh:MultiMesh=entry[0].multimesh;var seeds:PackedFloat32Array=entry[1]
  mesh.instance_count=seeds.size()/4
  for index in mesh.instance_count:mesh.set_instance_transform(index,Transform3D.IDENTITY);mesh.set_instance_custom_data(index,Color(seeds[index*4],seeds[index*4+1],seeds[index*4+2],seeds[index*4+3]))
 rng.state=int(generated.state);rng.calls=int(generated.calls)
 if initial_state.is_empty():initial=initial.duplicate(true);initial.thunder_timer=generated.thunder_timer
 time=float(initial.time);level=float(initial.get("level",.6));target=float(initial.get("target",.6));thunder_timer=float(initial.thunder_timer)
 for material in materials:material.set_shader_parameter("uTime",time);material.set_shader_parameter("uRain",level)

func set_rain(value:float)->void:target=clampf(value,0,1)

func update(dt:float,fov:float,height:float,interiors:Array,openings:Array)->void:
 time+=dt;level+=(target-level)*minf(1,dt*.8)
 pixel_width=2*tan(deg_to_rad(fov)*.5)/maxf(1,height)
 boxes_min.clear();boxes_max.clear()
 for index in 4:
  var box:Dictionary=interiors[index] if index<interiors.size() else {}
  boxes_min.append(_vec(box.min)+Vector3(-.15,-1,-.15) if box.has("min") and box.has("max") else Vector3.ZERO)
  boxes_max.append(_vec(box.max)+Vector3(.15,.3,.15) if box.has("min") and box.has("max") else Vector3.ZERO)
 drip=1 if not interiors.is_empty() else 0
 skylights.clear()
 for index in 8:
  var item:Dictionary=openings[index] if index<openings.size() else {}
  skylights.append(Vector4(item.x,item.z,item.w*.5,float(item.get("d",item.w) if item.get("d",0)!=0 else item.w)*.5) if item.get("w",0)>0 else Vector4(0,0,-1,-1))
 if rain!=null:
  rain.visible=level>.01;splash.visible=rain.visible
  for material in materials:
   material.set_shader_parameter("uTime",time);material.set_shader_parameter("uRain",level);material.set_shader_parameter("uBoxMin",boxes_min);material.set_shader_parameter("uBoxMax",boxes_max)
  materials[0].set_shader_parameter("uPix",pixel_width);materials[0].set_shader_parameter("uSky",skylights);materials[0].set_shader_parameter("uDrip",drip)
 thunder_timer-=dt
 if thunder_timer<=0:thunder_timer=30+rng.randf()*30;thunder.emit(.3+.7*rng.randf())

func _vec(value:Variant)->Vector3:return value if value is Vector3 else Vector3(value[0],value[1],value[2])

func verify_exported_seeds()->Dictionary:
 var checked=0;var maximum=0.0
 for record in scene.source.nodes:
  if record.name not in ["rain","rainSplash"]:continue
  var geometry:Dictionary=scene.geometry_records[record.geometry];var reference=scene._floats(geometry.attributes.aSeed)
  var node:MultiMeshInstance3D=scene.source_nodes[record.id]
  for index in node.multimesh.instance_count:
   var actual=node.multimesh.get_instance_custom_data(index)
   for component in 4:maximum=maxf(maximum,absf(actual[component]-reference[index*4+component]));checked+=1
 return {"float_components":checked,"maximum_error":maximum}
