extends RefCounted
static func apply(source:Dictionary,quality:String)->Dictionary:
 if quality in ["medium","high","ultra"]:
  if quality=="ultra":
   for material in source.materials:assert(material.userData.get("set","")!="asphalt","Ultra hero asphalt requires separate 2048 assets")
  source.quality=preload("res://scripts/render_quality.gd").PRESETS[quality].duplicate(true)
  return {"quality":quality,"texture_replacements":0}
 assert(quality=="low","Supported cold quality: low/medium/high/ultra")
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog/materials-full-low/catalog.json"))
 var ground=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ground/low/ground.json"))
 var original_textures={}
 for texture in source.textures:original_textures[texture.id]=texture
 var candidates={};var catalog_textures={};var replacements={};var material_count=0
 for texture in catalog.textures:catalog_textures[texture.id]=texture
 for material in catalog.materials:
  var set_name=str(material.userData.get("set",""))
  if not set_name.is_empty() and not candidates.has(set_name):candidates[set_name]=material
 for material in source.materials:
  var set_name=str(material.userData.get("set",""))
  if set_name.is_empty():continue
  assert(candidates.has(set_name),"Missing original low texture set "+set_name)
  var low=candidates[set_name]
  for key in ["map","normalMap","roughnessMap","metalnessMap","aoMap"]:
   var ref=material.props.get(key)
   if not ref is Dictionary:continue
   var low_ref=low.props.get(key);assert(low_ref is Dictionary)
   var texture=catalog_textures[low_ref["$texture"]];var id=ref["$texture"]
   if replacements.has(id):assert(replacements[id].source_sha256==texture.source_sha256,"Conflicting set mapping")
   replacements[id]=texture
  var width=catalog_textures[low.props.map["$texture"]].width
  var old_width=original_textures[material.props.map["$texture"]].width
  for uniforms in [material.userData.get("sl",{}),material.patch.get("uniforms",{})]:
   if uniforms.has("uSlUv") and uniforms.uSlUv.value[2]==old_width:uniforms.uSlUv.value[2]=width
  material_count+=1
 var ground_by_name={}
 for texture in ground.textures:ground_by_name[texture.name]=texture
 for material in source.materials:
  for uniforms in [material.get("uniforms",{}),material.get("patch",{}).get("uniforms",{})]:
   for name in ground_by_name:
    if uniforms.has(name):replacements[uniforms[name].value["$texture"]]=ground_by_name[name]
   if uniforms.has("uMarkRes"):uniforms.uMarkRes.value=ground.mark_resolution
   if uniforms.has("uMaskRes"):uniforms.uMaskRes.value=ground_by_name.uMask.width
 for index in source.textures.size():
  var old=source.textures[index]
  if not replacements.has(old.id):continue
  var replacement=old.duplicate(true);replacement.merge(replacements[old.id],true);replacement.id=old.id
  source.textures[index]=replacement
 source.quality=ground.quality.duplicate(true)
 return {"quality":quality,"texture_replacements":replacements.size(),"material_instances":material_count,"mask_resolution":ground_by_name.uMask.width}
