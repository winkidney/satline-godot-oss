extends RefCounted
static func build(record:Dictionary,materials:Array)->ArrayMesh:
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);var flags=0
 for pair in [["position",Mesh.ARRAY_VERTEX],["normal",Mesh.ARRAY_NORMAL]]:
  if not record.attributes.has(pair[0]):continue
  var values=PackedVector3Array();var raw=record.attributes[pair[0]]
  for i in range(0,raw.size(),3):values.append(Vector3(raw[i],raw[i+1],raw[i+2]))
  arrays[pair[1]]=values
 if record.attributes.has("uv"):
  var uv=PackedVector2Array();var raw=record.attributes.uv
  for i in range(0,raw.size(),2):uv.append(Vector2(raw[i],raw[i+1]))
  arrays[Mesh.ARRAY_TEX_UV]=uv
 if record.attributes.has("color"):
  var raw=record.attributes.color;var size=int(record.get("attribute_sizes",{}).get("color",3));var colors=PackedColorArray();var hdr=PackedFloat32Array()
  for i in range(0,raw.size(),size):
   var color=Color(raw[i],raw[i+1],raw[i+2],raw[i+3] if size==4 else 1.0);colors.append(color);hdr.append_array(PackedFloat32Array([color.r,color.g,color.b,color.a]))
  arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_CUSTOM3]=hdr;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
 var indices=PackedInt32Array(record.index)
 for i in range(0,indices.size(),3):
  var old=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=old
 var mesh=ArrayMesh.new()
 var groups=record.get("groups",[]) if materials.size()>1 else []
 if groups.is_empty():groups=[{"start":0,"count":indices.size(),"materialIndex":0}]
 for group in groups:
  arrays[Mesh.ARRAY_INDEX]=indices.slice(int(group.start),int(group.start+group.count));mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(mesh.get_surface_count()-1,materials[int(group.materialIndex)])
 return mesh
