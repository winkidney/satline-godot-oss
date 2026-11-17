extends RefCounted
static func attach(scene:SaltlineSourceScene,path:String="res://assets/catalog/materials/catalog.json",prepared:Dictionary={})->Node3D:
 var data=prepared if not prepared.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(path))
 for texture in data.textures:scene.texture_records[texture.id]=texture
 for record in data.materials:
  scene.source.materials.append(record)
  scene.source_material_masks[record.id]=1
  var material=scene._material(record)
  scene.materials[record.id]=material
 var geometries={};var meshes={};var variants={}
 for record in data.geometries:geometries[record.id]=record
 var group=Node3D.new();group.name="SourceMaterialCatalog"
 for record in data.nodes:
  var geometry=geometries[record.geometry];var ids:Array=record.get("materials",[record.material]);var bound=[]
  for id in ids:
   var key=id+"|"+str(geometry.attributes.has("color"))
   if not variants.has(key):
    var variant=scene.materials[id].duplicate()
    if not geometry.attributes.has("color"):variant.set_shader_parameter("vertex_color",false)
    variants[key]=variant
   bound.append(variants[key])
  var mesh_key=record.geometry+"|"+str(ids)
  if not meshes.has(mesh_key):meshes[mesh_key]=preload("res://scripts/catalog_mesh.gd").build(geometry,bound)
  var node:GeometryInstance3D
  if record.has("instanceCount"):
   var multi=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=record.has("instanceColor");mm.mesh=meshes[mesh_key];mm.instance_count=int(record.instanceCount)
   for i in mm.instance_count:
    mm.set_instance_transform(i,scene._transform(record.instanceMatrix.slice(i*16,i*16+16)))
    if mm.use_custom_data:mm.set_instance_custom_data(i,Color(record.instanceColor[i*3],record.instanceColor[i*3+1],record.instanceColor[i*3+2],1.0))
   if mm.use_custom_data:
    for material in bound:material.set_shader_parameter("instance_color",true)
   multi.multimesh=mm;node=multi
  else:
   var instance=MeshInstance3D.new();instance.mesh=meshes[mesh_key];node=instance
  node.name=record.name if not str(record.name).is_empty() else "CatalogMesh";node.set_meta("catalog_material",record.name);node.set_meta("catalog_prop",record.get("prop",""));node.visible=bool(record.get("visible",true));node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if record.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for material in bound:material.render_priority=clampi(int(record.get("renderOrder",0)),-128,127)
  node.transform=scene._transform(record.matrix);node.set_meta("source_id",record.id);group.add_child(node)
  scene.records[record.id]={"id":record.id,"geometry":record.geometry,"materials":ids,"receiveShadow":record.receiveShadow,"castShadow":record.castShadow}
  scene.source_nodes[record.id]=node
 scene.add_child(group)
 return group

static func set_wet(group:Node3D,value:float)->int:
 var changed={}
 for node in group.get_children():
  var mesh=node.mesh if node is MeshInstance3D else node.multimesh.mesh
  for surface in mesh.get_surface_count():
   var material=mesh.surface_get_material(surface)
   if material is ShaderMaterial and material.get_shader_parameter("wetness")!=null:
    material.set_shader_parameter("wetness",value);changed[material.get_instance_id()]=true
 return changed.size()
