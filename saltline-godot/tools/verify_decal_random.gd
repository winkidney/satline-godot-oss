extends SceneTree
var checks=0
var maximum_error=0.0
var failures=[]
var normal_codec_maximum=0.0
var normal_source_delta=0.0
var zero_normal_vertices=0
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/decal-random-reference.json"));var tape=[]
 for encoded in fixture.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_decals","id":"test"}]}
 var instance=MeshInstance3D.new();var quad=QuadMesh.new();quad.material=StandardMaterial3D.new();instance.mesh=quad;scene.source_nodes={"test":instance}
 var pool=SaltlineDecals.new(scene,rng)
 for row in fixture.rows:
  var op=row.op
  if op.get("clear",false):pool.clear()
  else:pool.add(Vector3(op.point[0],op.point[1],op.point[2]),Vector3(op.normal[0],op.normal[1],op.normal[2]),op.kind,float(op.size),float(op.shade),float(op.alpha))
  compare(rng.calls,row.calls,"calls",0)
  if row.expected==null:continue
  var actual=snapshot(pool)
  for key in ["count","next"]:compare(actual[key],row.expected[key],key,0)
  for key in ["position","uv","color"]:
   compare(actual[key].size(),row.expected[key].size(),key+" count",0)
   for i in mini(actual[key].size(),row.expected[key].size()):compare(actual[key][i],row.expected[key][i],str(row.get("index","clear"))+"/"+key+"/"+str(i),.000001)
  compare(actual.normal.size(),row.expected.normal.size(),"normal count",0)
  compare(actual.indices.size(),actual.count*6,"index count",0)
  for quad_index in actual.count:
   var base=quad_index*4;var expected_indices=[base,base+2,base+1,base,base+3,base+2]
   for k in 6:compare(actual.indices[quad_index*6+k],expected_indices[k],"Godot source-winding conversion",0)
  compare(actual.raw_normal.size(),actual.count*16,"raw normal count",0)
  for vertex in actual.normal.size()/3:
   var offset=vertex*3
   var original=Vector3(row.expected.normal[offset],row.expected.normal[offset+1],row.expected.normal[offset+2])
   var cpu:Vector3=pool.slots[vertex/4].normal
   for k in 3:
    compare(cpu[k],original[k],"CPU normal",.000001)
    compare(actual.raw_normal[vertex*4+k],original[k],"CUSTOM2 raw normal",.000001)
   if original.length_squared()==0:
    zero_normal_vertices+=1;continue
   var encoded=original.octahedron_encode()
   var packed=Vector2(float(clampi(int(PackedFloat32Array([encoded.x*65535.0])[0]),0,65535))/65535.0,float(clampi(int(PackedFloat32Array([encoded.y*65535.0])[0]),0,65535))/65535.0)
   var decoded=Vector3.octahedron_decode(packed)
   for k in 3:
    normal_source_delta=maxf(normal_source_delta,absf(actual.normal[offset+k]-original[k]))
    normal_codec_maximum=maxf(normal_codec_maximum,absf(actual.normal[offset+k]-decoded[k]))
    compare(actual.normal[offset+k],decoded[k],"normal oct16 codec",.000001)
 var report={"steps":fixture.rows.size(),"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"normal_codec_maximum":normal_codec_maximum,"normal_source_delta":normal_source_delta,"zero_normal_vertices":zero_normal_vertices,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":"Literal original Jg.add/clear and Yw UV function.175 emissions/160 ring, clear and re-emission, 7 kinds incl unknown, negative/default size, 5 normals incl zero/tiny, alpha fade; actual Native mesh position/UV/custom color buffers and CPU normals compared with source. Nonzero mesh normals compared with explicit engine oct16 codec; zero-normal degenerate faces excluded from codec assertion. CUSTOM2 raw normals and explicit Godot winding indices compared; shader-use GPU proof separate. No shaded-pixel equality claim."}
 FileAccess.open("res://evidence/decal-random-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));instance.free();scene.free();quit(0 if failures.is_empty() else 1)
func snapshot(pool:SaltlineDecals)->Dictionary:
 var value={"count":pool.slots.size(),"next":pool.next,"position":[],"normal":[],"uv":[],"color":[],"raw_normal":[],"indices":[]}
 if pool.slots.is_empty():return value
 var arrays=pool.mesh.mesh.surface_get_arrays(0)
 for key in ["position","normal"]:
  for point in arrays[Mesh.ARRAY_VERTEX if key=="position" else Mesh.ARRAY_NORMAL]:value[key].append_array([point.x,point.y,point.z])
 for uv in arrays[Mesh.ARRAY_TEX_UV]:value.uv.append_array([uv.x,uv.y])
 var colors=arrays[Mesh.ARRAY_CUSTOM3]
 if colors is PackedByteArray:colors=colors.to_float32_array()
 for color in colors:value.color.append(float(color))
 var raw=arrays[Mesh.ARRAY_CUSTOM2]
 if raw is PackedByteArray:raw=raw.to_float32_array()
 for value_component in raw:value.raw_normal.append(float(value_component))
 for index in arrays[Mesh.ARRAY_INDEX]:value.indices.append(int(index))
 return value
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
