extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var original:Dictionary={}
 for record in data.materials:
  if record.get("uniforms",{}).has("uDrip"):original=record
 var source=FileAccess.get_file_as_string("res://shaders/rain.gdshader");var code=source.left(source.find("void fragment(){"))
 code=code.replace("render_mode unshaded,blend_add,cull_disabled,depth_draw_never,fog_disabled;","render_mode unshaded,cull_disabled;")
 code=code.replace("shader_type spatial;","shader_type spatial;\nuniform vec3 probe_camera;varying float probe_kill;")
 code=code.replace("rain_camera=INV_VIEW_MATRIX[3].xyz","rain_camera=probe_camera")
 var line_start=code.find("  POSITION = kill");var line_end=code.find(";",line_start)
 code=code.left(line_start)+"probe_kill=kill;POSITION=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(VERTEX,1.0);"+code.substr(line_end+1)
 code+="void fragment(){ALBEDO=vec3(probe_kill);}"
 var shader=Shader.new();shader.code=code;var material=ShaderMaterial.new();material.shader=shader
 for key in original.uniforms:
  var value=original.uniforms[key].value
  if key in ["uBoxMin","uBoxMax"]:
   var array=PackedVector3Array()
   for row in value:array.append(Vector3(row[0],row[1],row[2]))
   material.set_shader_parameter(key,array)
  elif key=="uSky":
   var array=PackedVector4Array()
   for row in value:array.append(Vector4(row[0],row[1],row[2],row[3]))
   material.set_shader_parameter(key,array)
  elif value is Array:material.set_shader_parameter(key,Vector3(value[0],value[1],value[2]))
  else:material.set_shader_parameter(key,value)
 material.set_shader_parameter("uTime",0.0);material.set_shader_parameter("uRain",1.0)
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera=Camera3D.new();camera.position=Vector3(0,.5,2);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;viewport.add_child(camera);camera.current=true
 var env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.2,.2,.2);env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.5,0,0),Vector3(.5,0,0),Vector3(-.5,1,0),Vector3(.5,1,0)]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1,2,3,1]);var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.surface_set_material(0,material)
 var multi=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_custom_data=true;multi.mesh=mesh;multi.instance_count=1;multi.set_instance_transform(0,Transform3D.IDENTITY)
 var node=MultiMeshInstance3D.new();node.multimesh=multi;viewport.add_child(node)
 var cases=[
  {"name":"outdoor","point":Vector3(-24,2,6),"kill":false},
  {"name":"roof blocks","point":Vector3(-13,2,-15),"kill":true},
  {"name":"skylight passes","point":Vector3(-9.865,2,-14.1875),"kill":false},
  {"name":"below dry ground","point":Vector3(-24,-.2,6),"kill":true},
  {"name":"above water","point":Vector3(35,-1,6),"kill":false},
  {"name":"below water","point":Vector3(35,-2,6),"kill":true},
  {"name":"above roof","point":Vector3(-13,11,-15),"kill":false},
  {"name":"drip disabled","point":Vector3.ZERO,"drip":0,"kill":true},
  {"name":"drip enabled","point":Vector3.ZERO,"drip":1,"kill":false}]
 var failures=[];var samples=[]
 for row in cases:
  material.set_shader_parameter("probe_camera",row.point)
  if row.has("drip"):
   material.set_shader_parameter("uDrip",row.drip);multi.set_instance_custom_data(0,Color(.1,.2,.3,-1))
  else:multi.set_instance_custom_data(0,Color(row.point.x/26,row.point.y/15,row.point.z/26,.02))
  for frame in 2:await process_frame
  await RenderingServer.frame_post_draw
  var pixel=viewport.get_texture().get_image().get_pixel(32,32).r;var killed=pixel>.5
  if killed!=row.kill:failures.append(row.name)
  samples.append({"name":row.name,"expected_kill":row.kill,"actual_kill":killed,"red":pixel})
 var report={"failures":failures,"cases":cases.size(),"samples":samples,"scope":"Actual native rain vertex shader via INSTANCE_CUSTOM and original box/skylight uniforms; controlled positions/time, capture kill flag with forced probe clip geometry. Verifies outdoor/roof/skylight/ground/sea and negative-seed eave branch on GPU, not whole weather parity."}
 var file=FileAccess.open("res://evidence/rain-gpu-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
