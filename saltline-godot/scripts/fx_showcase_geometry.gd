extends RefCounted
static func build(scene:SaltlineSourceScene,physics:SaltlinePhysics)->Node3D:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fx-showcase-geometry.json"))
 var group=Node3D.new();group.name="SourceFXShowcase"
 for record in data.objects:
  var mesh=_mesh(record)
  var material_id=""
  for material in scene.source.materials:
   if material.name==record.material:material_id=material.id;mesh.surface_set_material(0,_uncolored_material(scene.materials[material.id]));break
  var node=MeshInstance3D.new();node.mesh=mesh;node.name=record.material;node.position=Vector3(record.position[0],record.position[1],record.position[2]);group.add_child(node)
  var id="fx-showcase-"+str(group.get_child_count())
  node.set_meta("source_id",id);scene.records[id]={"id":id,"geometry":id,"materials":[material_id],"receiveShadow":true,"castShadow":true};scene.source_nodes[id]=node
  physics.boxes.append({"min":Vector3(record.min[0],record.min[1],record.min[2]),"max":Vector3(record.max[0],record.max[1],record.max[2]),"surface":record.surface,"bulletOnly":false,"playerOnly":false})
 return group

static func isolate(scene:SaltlineSourceScene,physics:SaltlinePhysics)->Node3D:
 for node in scene.source_nodes.values():
  if scene.records.get(str(node.get_meta("source_id","")),{}).get("name","")=="sky":
   node.visible=true
   continue
  if node is GeometryInstance3D or node is OmniLight3D:node.visible=false
 physics.boxes.clear()
 var group=build(scene,physics)
 var ground=MeshInstance3D.new();ground.name="ShowcaseGround"
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fx-showcase-geometry.json"))
 ground.mesh=_mesh(data.ground);ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for material in scene.source.materials:
  if material.name=="concrete":ground.material_override=_uncolored_material(scene.materials[material.id]);break
 group.add_child(ground)
 return group

static func _uncolored_material(source:Material)->Material:
 var material=source.duplicate()
 # THREE only enables USE_COLOR when geometry supplies the attribute; these
 # original Ei/Plane geometries have none despite material.vertexColors=true.
 if material is ShaderMaterial:material.set_shader_parameter("vertex_color",false)
 return material

static func _mesh(record:Dictionary)->ArrayMesh:
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 for pair in [["position",Mesh.ARRAY_VERTEX],["normal",Mesh.ARRAY_NORMAL]]:
  var values=PackedVector3Array();var raw=record.attributes[pair[0]]
  for i in range(0,raw.size(),3):values.append(Vector3(raw[i],raw[i+1],raw[i+2]))
  arrays[pair[1]]=values
 var uv=PackedVector2Array()
 for i in range(0,record.attributes.uv.size(),2):uv.append(Vector2(record.attributes.uv[i],record.attributes.uv[i+1]))
 arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(record.index)
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh
