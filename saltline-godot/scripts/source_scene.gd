class_name SaltlineSourceScene
extends Node3D

var tri_palette=preload("res://scripts/triplanar_palette.gd").new()
var sight_materials:Array=[]
var sight_environment=SaltlineSightEnvironment.new()
var sight_environment_intensity=1.0
var source:Dictionary
var source_nodes:Dictionary={}
var records:Dictionary={}
var meshes:Dictionary={}
var materials:Dictionary={}
var textures:Dictionary={}
var source_row_textures:Dictionary={}
var generic_shader_variants:Dictionary={}
var texture_records:Dictionary={}
var geometry_records:Dictionary={}
var source_material_masks:Dictionary={}
var source_polygon_supported=false
var camera:Camera3D
var weapon_wetness=1.0
var backdrop_time=0.0
var backdrop_showcase=false
var backdrop_motion={}
var backdrop_rest={}
var weapon_detail_materials:Array=[]
var weapon_wet_materials:Array=[]
var backdrop_materials:Array=[]
var skeletons:Dictionary={}
var skin_bindings:Array=[]
var bone_targets:Dictionary={}
var report:Dictionary={"nodes":0,"meshes":0,"materials":0,"textures":0,"pending_shaders":[],"source_skin_reference_meshes":0}
# shortcut: fixed exported geometry ID, re-identify the wall after re-export.
const QUAY_WALL_GEOMETRY="2f646d8b-232d-4329-9355-48f6768c0c27"

func load_source(progress:Callable=Callable()) -> void:
 if progress.is_valid():await progress.call("Mixing paint, rust and rain",.12)
 source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var device=preload("res://scripts/device_quality.gd").detect()
 var cold_quality=str(device.quality)
 report["device_quality"]=device
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--cold-quality="):cold_quality=arg.trim_prefix("--cold-quality=")
 report["cold_quality_assets"]=preload("res://scripts/cold_quality_assets.gd").apply(source,cold_quality)
 _prepare_source_polygon_support()
 var material_orders={};var node_records={}
 for record in source.nodes:node_records[record.id]=record
 var order_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/node-render-order-bindings.json"))
 for binding in order_data.bindings:
  if not node_records.has(binding.id):push_error("Unknown render-order source node "+str(binding.id));continue
  if binding.groupOrder!=0:push_error("Unsupported nonzero source group order");continue
  for id in node_records[binding.id].get("materials",[]):
   if material_orders.has(id) and material_orders[id]!=int(binding.renderOrder):push_error("Conflicting source per-node material order "+id)
   material_orders[id]=int(binding.renderOrder)
 for record in source.textures:texture_records[record.id]=record
 for record in source.geometries:geometry_records[record.id]=record
 for record in source.nodes:
  for id in record.get("materials",[]):source_material_masks[id]=int(source_material_masks.get(id,0))|int(record.layers)
 for record in source.materials:
  var material=_material(record);material.set_meta("source_material_id",record.id);materials[record.id]=material
  # Sky/rain use existing extreme-order compression; finite ordinary source
  # priorities fit Godot directly and are consistent across shared instances.
  if material_orders.has(record.id) and absi(int(material_orders[record.id]))<=127:material.render_priority=int(material_orders[record.id])
 for record in source.nodes:records[record.id]=record
 if progress.is_valid():await progress.call("Stacking containers",.34)
 for record in source.nodes:
  var node:Node3D
  if record.type=="PerspectiveCamera":
   camera=Camera3D.new();camera.fov=record.camera.fov;camera.near=record.camera.near;camera.far=record.camera.far;camera.current=true
   camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.cull_mask=3;node=camera
  elif record.type=="PointLight" and records.get(record.parent,{}).get("name","")=="level-dynamic":
   var light=OmniLight3D.new();var properties=record.light;var rgb=properties.color;light.light_color=Color(rgb[0],rgb[1],rgb[2]).linear_to_srgb();light.set_meta("source_intensity",float(properties.intensity));light.light_energy=float(properties.intensity)/PI;light.omni_range=float(properties.distance);light.omni_attenuation=float(properties.decay);light.light_cull_mask=int(record.layers)|4;light.shadow_enabled=bool(record.castShadow);light.set_meta("source_light_role","static-level");node=light
   report["source_static_point_lights"]=int(report.get("source_static_point_lights",0))+1
  elif record.has("geometry"):
   if geometry_records[record.geometry].attributes.has("aSeed"):
    var multi=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
    mm.mesh=_mesh(record.geometry,record)
    var seeds=_floats(geometry_records[record.geometry].attributes.aSeed);mm.instance_count=int(seeds.size()/4)
    for index in mm.instance_count:
     mm.set_instance_transform(index,Transform3D.IDENTITY);mm.set_instance_custom_data(index,Color(seeds[index*4],seeds[index*4+1],seeds[index*4+2],seeds[index*4+3]))
    mm.custom_aabb=AABB(Vector3(-1000,-1000,-1000),Vector3(2000,2000,2000));multi.multimesh=mm;node=multi
   elif record.has("instanceCount"):
    var multi=MultiMeshInstance3D.new();var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.use_custom_data=record.has("instanceColor")
    mm.mesh=_mesh(record.geometry,record);mm.instance_count=int(record.instanceCount)
    for i in mm.instance_count:mm.set_instance_transform(i,_transform(record.instanceMatrix.slice(i*16,i*16+16)))
    if record.has("instanceColor"):
     for i in mm.instance_count:mm.set_instance_custom_data(i,Color(record.instanceColor[i*3],record.instanceColor[i*3+1],record.instanceColor[i*3+2],1))
     var material=mm.mesh.surface_get_material(0).duplicate();material.set_shader_parameter("instance_color",true);multi.material_override=material
    multi.multimesh=mm;node=multi
   else:
    var instance=MeshInstance3D.new();instance.mesh=_mesh(record.geometry,record);node=instance
   var mesh=node as GeometryInstance3D
   if geometry_records[record.geometry].attributes.has("aOrbit"):mesh.custom_aabb=_backdrop_bounds(geometry_records[record.geometry])
   mesh.layers=int(record.layers);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if record.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   if record.has("posedPositions"):report.source_skin_reference_meshes+=1
  else:node=Node3D.new()
  node.name=_safe_name(record.name,record.id);node.set_meta("source_id",record.id);node.transform=_transform(record.matrix)
  node.visible=bool(record.visible);source_nodes[record.id]=node
  if record.name=="sky":
   (node as MeshInstance3D).custom_aabb=AABB(Vector3(-2000,-2000,-2000),Vector3(4000,4000,4000))
 if progress.is_valid():await progress.call("Raising the cranes",.5)
 for record in source.nodes:
  var node:Node3D=source_nodes[record.id]
  if record.parent!=null and source_nodes.has(record.parent):source_nodes[record.parent].add_child(node)
  else:add_child(node)
 _bind_skeletons()
 for binding in skin_bindings:
  for i in binding.bones.size():
   var id:String=binding.bones[i]
   if not bone_targets.has(id):bone_targets[id]=[]
   if not bone_targets[id].any(func(target):return target[0]==binding.skeleton and target[1]==i):bone_targets[id].append([binding.skeleton,i])
 tri_palette.setup(self)
 _bind_backdrop_motion()
 report["triplanar_palette"]=tri_palette.report
 report["generic_sampler_variants"]=generic_shader_variants.size()
 report.nodes=source_nodes.size();report.materials=materials.size();var unique_textures=textures.duplicate();unique_textures.merge(source_row_textures)
 report.textures=unique_textures.size();report["gpu_texture_variants"]=textures.size()+source_row_textures.size();report.meshes=meshes.size()

func set_source_transform(id:String,pose:Transform3D)->void:
 source_nodes[id].transform=pose
 for target in bone_targets.get(id,[]):target[0].set_bone_pose(target[1],pose)

func _safe_name(label:String,id:String)->String:
 return (label if label!="" else "source")+"_"+id.substr(0,8)

func _transform(values:Array)->Transform3D:
 return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[4],values[5],values[6]),Vector3(values[8],values[9],values[10])),Vector3(values[12],values[13],values[14]))

func _floats(attr:Dictionary)->PackedFloat32Array:
 var file="res://assets/export/"+str(attr.file)
 return FileAccess.get_file_as_bytes(file).to_float32_array()

func _vec3(attr:Dictionary)->PackedVector3Array:
 var floats=_floats(attr);var out=PackedVector3Array();out.resize(int(attr.count))
 for i in out.size():out[i]=Vector3(floats[i*attr.itemSize],floats[i*attr.itemSize+1],floats[i*attr.itemSize+2])
 return out

func _separate_quay_wall(vertices:PackedVector3Array)->PackedVector3Array:
 var corners:Array[int]=[]
 for i in vertices.size():
  var p=vertices[i]
  if is_equal_approx(p.x,30.0) and (is_equal_approx(p.y,-.002) or is_equal_approx(p.y,-.67)) and (is_equal_approx(p.z,-30.97) or is_equal_approx(p.z,19.55)):corners.append(i)
 if corners.size()!=24:
  push_error("Unexpected quay wall geometry");return vertices
 # The quay wall shares its face with the far foundation.
 for i in corners:
  var p=vertices[i];p.x+=.005;vertices[i]=p
 return vertices

func _mesh(id:String,node_record:Dictionary)->ArrayMesh:
 var key=id+"|"+str(node_record.materials)
 # Skin attributes share the original geometry; poses are driven by Skeleton3D.
 if meshes.has(key):return meshes[key]
 var geo:Dictionary=geometry_records[id];var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 var flags:int=0
 var vertices=_vec3(geo.attributes.position)
 if id==QUAY_WALL_GEOMETRY:vertices=_separate_quay_wall(vertices)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 if geo.attributes.has("normal"):arrays[Mesh.ARRAY_NORMAL]=_vec3(geo.attributes.normal)
 if geo.attributes.has("uv"):
  var a:Dictionary=geo.attributes.uv;var f=_floats(a);var uv=PackedVector2Array();uv.resize(int(a.count))
  for i in uv.size():uv[i]=Vector2(f[i*2],f[i*2+1])
  arrays[Mesh.ARRAY_TEX_UV]=uv
 if geo.attributes.has("color"):
  var a:Dictionary=geo.attributes.color;var f=_floats(a);var colors=PackedColorArray();colors.resize(int(a.count))
  for i in colors.size():colors[i]=Color(f[i*a.itemSize],f[i*a.itemSize+1],f[i*a.itemSize+2],f[i*a.itemSize+3] if a.itemSize==4 else 1.0)
  arrays[Mesh.ARRAY_COLOR]=colors
  var hdr=PackedFloat32Array();hdr.resize(int(a.count)*4)
  for i in colors.size():hdr[i*4]=colors[i].r;hdr[i*4+1]=colors[i].g;hdr[i*4+2]=colors[i].b;hdr[i*4+3]=colors[i].a
  arrays[Mesh.ARRAY_CUSTOM3]=hdr;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
 for slot in 3:
  var attr_name=["aSurf","aRest","aHand"][slot]
  if geo.attributes.has(attr_name):
   arrays[Mesh.ARRAY_CUSTOM0+slot]=_floats(geo.attributes[attr_name])
   flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<[Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT][slot]
 for pair in [["blink",0],["aOrbit",0],["aPar",1]]:
  if geo.attributes.has(pair[0]):
   var attribute:Dictionary=geo.attributes[pair[0]];var values=_floats(attribute);var packed=PackedFloat32Array();packed.resize(int(attribute.count)*4)
   for vertex in int(attribute.count):
    for channel in int(attribute.itemSize):packed[vertex*4+channel]=values[vertex*int(attribute.itemSize)+channel]
   arrays[Mesh.ARRAY_CUSTOM0+pair[1]]=packed;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<[Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT][pair[1]]
 if geo.attributes.has("aSurf"):
  # Original detail reads the unquantized object normal. Godot's native
  # normal channel uses octahedral packing, so preserve source FP32 separately.
  var normals=_floats(geo.attributes.normal);var packed=PackedFloat32Array();packed.resize(int(geo.attributes.normal.count)*4)
  for i in int(geo.attributes.normal.count):packed[i*4]=normals[i*3];packed[i*4+1]=normals[i*3+1];packed[i*4+2]=normals[i*3+2]
  arrays[Mesh.ARRAY_CUSTOM2]=packed;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
 if geo.attributes.has("skinIndex"):
  var attr:Dictionary=geo.attributes.skinIndex;var bytes=FileAccess.get_file_as_bytes("res://assets/export/"+attr.file)
  var bones=PackedInt32Array();bones.resize(int(attr.count)*4)
  for i in bones.size():bones[i]=bytes.decode_u16(i*2)
  arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=_floats(geo.attributes.skinWeight)
 if geo.attributes.has("aRest") and not geo.attributes.has("aSurf"):
  var normal_values=_floats(geo.attributes.normal);var packed=PackedFloat32Array();packed.resize(int(geo.attributes.normal.count)*4)
  for i in int(geo.attributes.normal.count):packed[i*4]=normal_values[i*3];packed[i*4+1]=normal_values[i*3+1];packed[i*4+2]=normal_values[i*3+2];packed[i*4+3]=0.0
  arrays[Mesh.ARRAY_CUSTOM0]=packed;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
 if geo.attributes.has("aType"):
  var values=_floats(geo.attributes.aType);var packed=PackedFloat32Array();packed.resize(values.size()*4)
  for i in values.size():packed[i*4]=values[i]
  arrays[Mesh.ARRAY_CUSTOM0]=packed;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
 if geo.attributes.has("skinIndex"):
  var is_tri=false
  for material_id in node_record.materials:
   if materials[material_id] is ShaderMaterial and materials[material_id].get_shader_parameter("triplanar")==true:is_tri=true
  if is_tri:
   for pair in [["position",Mesh.ARRAY_CUSTOM1,Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT],["normal",Mesh.ARRAY_CUSTOM2,Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT]]:
    var values=_floats(geo.attributes[pair[0]]);var packed=PackedFloat32Array();packed.resize(int(geo.attributes[pair[0]].count)*4)
    for i in int(geo.attributes[pair[0]].count):packed[i*4]=values[i*3];packed[i*4+1]=values[i*3+1];packed[i*4+2]=values[i*3+2]
    arrays[pair[1]]=packed;flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<pair[2]
 var indices=FileAccess.get_file_as_bytes(geo.godot_index).to_int32_array()
 var mesh=ArrayMesh.new()
 if node_record.materials.size()==1:
  arrays[Mesh.ARRAY_INDEX]=indices;mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags);mesh.surface_set_material(0,materials[node_record.materials[0]])
 else:
  for group in geo.groups:
   arrays[Mesh.ARRAY_INDEX]=indices.slice(int(group.start),int(group.start+group.count));mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
   mesh.surface_set_material(mesh.get_surface_count()-1,materials[node_record.materials[int(group.materialIndex)]])
 meshes[key]=mesh;return mesh

func _texture(reference:Variant,original_rows:bool=false)->Texture2D:
 if reference==null or not reference is Dictionary or not reference.has("$texture"):return null
 var id:String=reference["$texture"]
 var cache=source_row_textures if original_rows else textures
 if cache.has(id):return cache[id]
 if not texture_records.has(id):return null
 var record:Dictionary=texture_records[id]
 if not record.has("godot_file"):return null
 var image:Image
 if record.has("godot_mip_file"):
  image=Image.create_from_data(int(record.width),int(record.height),bool(record.godot_has_mipmaps),Image.FORMAT_RGBA8,FileAccess.get_file_as_bytes(record.godot_source_mip_file if original_rows else record.godot_mip_file))
 else:
  var imported:Texture2D=load(record.godot_file);image=imported.get_image()
  if int(record.get("minFilter",1008)) not in [1003,1006]:image.generate_mipmaps()
 var texture=ImageTexture.create_from_image(image);cache[id]=texture;return texture

func _v3(value:Variant,fallback:Vector3)->Vector3:
 if not value is Array:return fallback
 return Vector3(value[0],value[1],value[2])

func _prepare_source_polygon_support()->void:
 var requested=bool(ProjectSettings.get_setting("rendering/saltline/source_depth_24",false));var reason="disabled";var device=RenderingServer.get_rendering_device();source_polygon_supported=false
 if requested:
  if not str(Engine.get_version_info().status).contains("source_bias"):reason="requires isolated source_bias engine"
  elif RenderingServer.get_current_rendering_method()!="forward_plus":reason="private hardware bias requires Forward+ renderer"
  elif device==null:reason="RenderingDevice unavailable"
  else:
   var usage=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
   source_polygon_supported=device.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT,usage) and device.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT,usage|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT)
   reason="supported" if source_polygon_supported else "D24 attachment/sampling/copy-from usage unsupported"
  if not source_polygon_supported:push_warning("Source D24 hardware bias disabled: "+reason+"; ordinary depth/offset fallback remains approximate")
 report["source_polygon_offset"]={"requested":requested,"supported":source_polygon_supported,"reason":reason}

func _source_polygon_mode(props:Dictionary,source_mask:int)->String:
 if not props.get("polygonOffset",false) or not ProjectSettings.get_setting("rendering/saltline/source_depth_24",false):return ""
 if not source_polygon_supported:return ""
 var factor=float(props.get("polygonOffsetFactor",0));var units=float(props.get("polygonOffsetUnits",0))
 if factor!=units or factor not in [-2.0,-3.0,-4.0] or (source_mask&3)==3:push_error("Unsupported source polygon offset combination");return ""
 if (source_mask&2)!=0:
  if factor!=-3.0:push_error("Unsupported source weapon polygon offset");return ""
  return "saltline_bias_weapon_3"
 return "saltline_bias_world_"+str(int(-factor))

func _generic_shader(path:String,props:Dictionary,source_mask:int=0)->Shader:
 var original:Shader=load(path);var code=original.code
 var bias_mode=_source_polygon_mode(props,source_mask)
 if not bias_mode.is_empty():
  var end=code.find(";",code.find("render_mode "));code=code.substr(0,end)+","+bias_mode+code.substr(end)
 for pair in [["map","albedo_tex"],["roughnessMap","orm_tex"],["normalMap","normal_tex"]]:
  var reference=props.get(pair[0])
  if not reference is Dictionary or not reference.has("$texture"):continue
  var record=texture_records[reference["$texture"]]
  var wrapping="repeat_disable" if int(record.get("wrapS",1000))==1001 and int(record.get("wrapT",1000))==1001 else "repeat_enable"
  var filtering="filter_linear" if int(record.get("minFilter",1008))==1006 else "filter_linear_mipmap" if float(record.get("anisotropy",8))<=1 else "filter_linear_mipmap_anisotropic_4" if float(record.get("anisotropy",8))==4 else "filter_linear_mipmap_anisotropic"
  var prefix="uniform sampler2D "+pair[1]+":";var start=code.find(prefix)
  if start<0:continue
  var end=code.find(";",start);var declaration=code.substr(start,end-start)
  var replacement=declaration.replace("repeat_enable",wrapping).replace("filter_linear_mipmap_anisotropic",filtering)
  code=code.substr(0,start)+replacement+code.substr(end)
 var key=path+"|"+code.sha256_text()
 if generic_shader_variants.has(key):return generic_shader_variants[key]
 var shader=original
 if code!=original.code:
  shader=Shader.new();shader.code=code;shader.set_meta("source_shader_path",path)
 if not bias_mode.is_empty():shader.set_meta("source_polygon_offset_mode",bias_mode)
 generic_shader_variants[key]=shader;return shader

func _material(record:Dictionary)->Material:
 var p:Dictionary=record.props
 if record.name=="sea":return _sea_material(record)
 if record.name=="apron_wet":return _ground_material(record)
 if record.name=="saltline_arm":
  var arm=ShaderMaterial.new();arm.shader=load("res://shaders/arms.gdshader");arm.set_shader_parameter("uArmWet",record.patch.uniforms.uArmWet.value);weapon_wet_materials.append([arm,"uArmWet"]);return arm
 if record.type=="ShaderMaterial":
  if record.name=="saltline-sky":return _sky_material(record)
  if record.uniforms.has("uRain"):return _rain_material(record)
  if record.uniforms.has("uBright") and record.uniforms.has("uTilt"):
   var sight=ShaderMaterial.new();sight.shader=load("res://shaders/sight_glass.gdshader");sight.render_priority=5
   for parameter in record.uniforms:
    var value=record.uniforms[parameter].value
    sight.set_shader_parameter(parameter,_v3(value,Vector3.ZERO) if value is Array else value)
   sight_materials.append(sight);return sight
  if record.uniforms.has("uGain") and record.uniforms.has("uColor"):
   var cone=ShaderMaterial.new();cone.shader=load("res://shaders/gull_light_cone.gdshader");cone.set_shader_parameter("uGain",record.uniforms.uGain.value)
   var value:Array=record.uniforms.uColor.value;cone.set_shader_parameter("uColor",Vector3(value[0],value[1],value[2]));return cone
  if record.uniforms.has("uJet"):
   var flash=ShaderMaterial.new();flash.shader=load("res://shaders/muzzle_flash.gdshader")
   for parameter in record.uniforms:flash.set_shader_parameter(parameter,record.uniforms[parameter].value)
   return flash
  report.pending_shaders.append({"id":record.id,"name":record.name,"uniforms":record.uniforms.keys()})
  var pending=StandardMaterial3D.new();pending.albedo_color=Color(.12,.15,.18);pending.cull_mode=BaseMaterial3D.CULL_DISABLED
  return pending
 var shader_path="res://shaders/source_material_alpha.gdshader" if p.get("transparent",false) else "res://shaders/source_material.gdshader"
 if record.type=="MeshBasicMaterial":shader_path="res://shaders/source_material_basic_alpha.gdshader" if p.get("transparent",false) else "res://shaders/source_material_basic.gdshader"
 var m=ShaderMaterial.new();m.set_meta("source_material_id",record.get("id",""));m.shader=_generic_shader(shader_path,p,int(source_material_masks.get(record.id,0)));m.set_meta("source_polygon_offset_mode",m.shader.get_meta("source_polygon_offset_mode",""));m.set_shader_parameter("source_tri_palette",tri_palette.texture);m.set_shader_parameter("material_side",int(p.get("side",0)))
 if record.name=="fx_decals":m.set_shader_parameter("source_exact_normal",true)
 m.set_shader_parameter("base_color",_v3(p.get("color"),Vector3.ONE))
 m.set_shader_parameter("has_ao_map",p.get("aoMap")!=null);m.set_shader_parameter("roughness_value",p.get("roughness",1.0));m.set_shader_parameter("metallic_value",p.get("metalness",0.0))
 m.set_shader_parameter("vertex_color",p.get("vertexColors",false));m.set_shader_parameter("opacity_value",p.get("opacity",1.0));m.set_shader_parameter("alpha_cut",p.get("alphaTest",0.0))
 m.set_shader_parameter("normal_scale",Vector2(p.normalScale[0],p.normalScale[1]) if p.has("normalScale") else Vector2.ONE)
 var emission=_v3(p.get("emissive"),Vector3.ZERO)*float(p.get("emissiveIntensity",1.0))
 if record.type=="MeshBasicMaterial":emission=_v3(p.get("color"),Vector3.ONE)
 m.set_shader_parameter("emission_color",emission)
 var defines:Dictionary=p.get("defines",{})
 m.set_shader_parameter("distance_alpha_cut",defines.has("SL_ACUT"));m.set_shader_parameter("tint_mode",int(defines.get("SL_TINT",0)));m.set_shader_parameter("triplanar",defines.has("SL_TRIPLANAR"));m.set_shader_parameter("sl_fx",defines.has("SL_FX"))
 var sl:Dictionary=record.userData.get("sl",{})
 if sl.has("uSlWet"):m.set_shader_parameter("wetness",float(sl.uSlWet.value))
 m.set_shader_parameter("source_material_patch",not sl.is_empty());m.set_shader_parameter("source_noise_round_guard",0)
 m.set_shader_parameter("source_markings_bump",str(record.get("patch",{}).get("fragmentShader","")).contains("normal = dBump(normal, -diffuseColor.a * 0.00005);"))
 var patch_code=str(record.get("onBeforeCompile",""));var backdrop_mode=1 if patch_code.contains("varying float vBlink") else 2 if patch_code.contains("aOrbit") else 0
 if backdrop_mode!=0:
  m.set_shader_parameter("source_backdrop_mode",backdrop_mode);m.set_shader_parameter("source_backdrop_time",float(record.patch.uniforms.uTime.value));backdrop_materials.append(m)
 var detail_pattern=RegEx.new();detail_pattern.compile("#define D_KIND ([0-9]+)");var detail_match=detail_pattern.search(str(record.get("patch",{}).get("fragmentShader","")))
 if detail_match!=null:
  m.set_shader_parameter("source_weapon_kind",int(detail_match.get_string(1)));m.set_shader_parameter("source_weapon_rain",float(record.patch.uniforms.uRain.value));m.set_shader_parameter("source_weapon_noise_round_guard",0);weapon_detail_materials.append(m);weapon_wet_materials.append([m,"source_weapon_rain"])
 for pair in [["uSlWetP","wet_params"],["uSlMacro","macro_params"]]:
  if sl.has(pair[0]):
   var a:Array=sl[pair[0]].value;m.set_shader_parameter(pair[1],Vector4(a[0],a[1],a[2],a[3]))
 if sl.has("uSlX"):m.set_shader_parameter("interior",sl.uSlX.value[0])
 if sl.has("uSlUv"):
  m.set_shader_parameter("tri_scale",sl.uSlUv.value[2]);m.set_shader_parameter("source_uv_scale",Vector2(sl.uSlUv.value[0],sl.uSlUv.value[1]))
 for pair in [["map","albedo_tex","has_map"],["roughnessMap","orm_tex","has_orm"],["normalMap","normal_tex","has_normal"]]:
  var texture=_texture(p.get(pair[0]),true);m.set_shader_parameter(pair[2],texture!=null)
  if texture:m.set_shader_parameter(pair[1],texture)
 if p.get("map") is Dictionary:
  var tr:Dictionary=texture_records[p.map["$texture"]];m.set_shader_parameter("uv_repeat",Vector2(tr.repeat[0],tr.repeat[1]));m.set_shader_parameter("uv_offset",Vector2(tr.offset[0],tr.offset[1]))
 return m

func _bind_skeletons()->void:
 var max_error=0.0;var vertices_checked=0
 for record in source.nodes:
  if not record.has("skin"):continue
  var instance:MeshInstance3D=source_nodes[record.id]
  var skin_record:Dictionary=record.skin
  var group:Node3D=instance.get_parent()
  var key=str(skin_record.bones)
  var skeleton:Skeleton3D
  if skeletons.has(key):skeleton=skeletons[key]
  else:
   skeleton=Skeleton3D.new();skeleton.name="SourceSkeleton_"+record.id.substr(0,8);group.add_child(skeleton)
   for id in skin_record.bones:skeleton.add_bone(str(records[id].name) if records[id].name!="" else "bone_"+str(skeleton.get_bone_count()))
   for i in skin_record.bones.size():
    var bone:Dictionary=records[skin_record.bones[i]]
    var parent=skin_record.bones.find(bone.parent)
    skeleton.set_bone_parent(i,parent)
    var rest=_transform(skin_record.boneInverses[i]).affine_inverse()
    if parent>=0:rest=_transform(skin_record.boneInverses[parent])*rest
    skeleton.set_bone_rest(i,rest);skeleton.set_bone_pose(i,_transform(bone.matrix))
   skeletons[key]=skeleton
  var skin=Skin.new()
  for i in skin_record.bones.size():skin.add_bind(i,_transform(skin_record.boneInverses[i]))
  instance.skeleton=instance.get_path_to(skeleton);instance.skin=skin
  skin_bindings.append({"mesh":record.id,"skeleton":skeleton,"bones":skin_record.bones})
  skeleton.force_update_all_bone_transforms()
  var geo:Dictionary=geometry_records[record.geometry]
  var pos=_vec3(geo.attributes.position);var expected=_vec3(record.posedPositions)
  var weights=_floats(geo.attributes.skinWeight);var indices=FileAccess.get_file_as_bytes("res://assets/export/"+geo.attributes.skinIndex.file)
  for v in range(0,pos.size(),maxi(1,pos.size()/24)):
   var actual=Vector3.ZERO
   for j in 4:
    var bone_index=indices.decode_u16((v*4+j)*2)
    actual+=(skeleton.get_bone_global_pose(bone_index)*skin.get_bind_pose(bone_index)*pos[v])*weights[v*4+j]
   max_error=maxf(max_error,actual.distance_to(expected[v]));vertices_checked+=1
 report["native_skeletons"]=skeletons.size();report["native_skin_meshes"]=skin_bindings.size();report["skin_reference_vertices_checked"]=vertices_checked;report["skin_reference_max_error_m"]=max_error

func _ground_material(record:Dictionary)->ShaderMaterial:
 var m=ShaderMaterial.new();m.shader=load("res://shaders/ground.gdshader")
 for name in record.patch.uniforms:
  var value=record.patch.uniforms[name].value
  if value is Dictionary and value.has("$texture"):
   var texture=_texture(value)
   if texture:m.set_shader_parameter(name,texture)
  elif value is Array:
   if value.size()==2:m.set_shader_parameter(name,Vector2(value[0],value[1]))
   elif value.size()==3:m.set_shader_parameter(name,Vector3(value[0],value[1],value[2]))
   elif value.size()==4:m.set_shader_parameter(name,Vector4(value[0],value[1],value[2],value[3]))
  elif value is float or value is int:m.set_shader_parameter(name,value)
 # Export captured an active original render-target; do not reuse its stale matrix/texture as a live pass.
 m.set_shader_parameter("uReflOn",0.0)
 return m

func update_sight_environment()->void:
 var value=sight_environment.update(sight_environment_intensity)
 for material in sight_materials:material.set_shader_parameter("uEnv",value)

func _sea_material(record:Dictionary)->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=load("res://shaders/sea.gdshader")
 for parameter in record.patch.uniforms:
  var value=record.patch.uniforms[parameter].value
  material.set_shader_parameter(parameter,_texture(value) if value is Dictionary else _v3(value,Vector3.ZERO) if value is Array else value)
 return material

func _rain_material(record:Dictionary)->ShaderMaterial:
 var material=ShaderMaterial.new();var is_drip=record.uniforms.has("uDrip")
 material.shader=load("res://shaders/rain.gdshader" if is_drip else "res://shaders/rain_splash.gdshader");material.render_priority=100 if is_drip else 99
 for parameter in record.uniforms:
  var value=record.uniforms[parameter].value
  if parameter in ["uBoxMin","uBoxMax"]:
   var vectors=PackedVector3Array()
   for item in value:vectors.append(_v3(item,Vector3.ZERO))
   material.set_shader_parameter(parameter,vectors)
  elif parameter=="uSky":
   var vectors=PackedVector4Array()
   for item in value:vectors.append(Vector4(item[0],item[1],item[2],item[3]))
   material.set_shader_parameter(parameter,vectors)
  else:material.set_shader_parameter(parameter,_texture(value) if value is Dictionary else _v3(value,Vector3.ZERO) if value is Array else value)
 return material

func _sky_material(record:Dictionary)->ShaderMaterial:
 var material=ShaderMaterial.new();material.shader=load("res://shaders/dynamic_sky.gdshader");material.render_priority=-128
 for parameter in record.uniforms:
  var value=record.uniforms[parameter].value
  if parameter=="tNoise":
   var record_texture:Dictionary=texture_records[value["$texture"]]
   var image=Image.create_from_data(record_texture.width,record_texture.height,false,Image.FORMAT_RGBA8,FileAccess.get_file_as_bytes("res://assets/export/"+record_texture.file))
   var texture=ImageTexture.create_from_image(image);textures[record_texture.id]=texture;material.set_shader_parameter(parameter,texture)
  else:material.set_shader_parameter(parameter,_v3(value,Vector3.ZERO) if value is Array else value)
 return material

func update_weapon_wetness(dt:float,inside:bool)->void:
 var step=minf(dt,.05);var target=.3 if inside else 1.0
 weapon_wetness+=(target-weapon_wetness)*minf(1.0,step*(.25 if inside else .6))
 for binding in weapon_wet_materials:binding[0].set_shader_parameter(binding[1],weapon_wetness)

func update_backdrop_time(time:float)->void:
 backdrop_time=time
 if backdrop_motion.has("shed_fan"):_backdrop_rotation("shed_fan",time*1.7,0,0)
 for material in backdrop_materials:material.set_shader_parameter("source_backdrop_time",time)
 if backdrop_motion.has("spreader"):
  _backdrop_rotation("spreader",.012*sin(time*.52)+.004*sin(time*1.31+1),backdrop_rest.spreader.rotation.y,.009*sin(time*.41+1.1))
 if backdrop_motion.has("radar"):_backdrop_rotation("radar",backdrop_rest.radar.rotation.x,time*1.9,backdrop_rest.radar.rotation.z)
 if backdrop_motion.has("boat"):
  var position:Vector3=backdrop_motion.boat.position
  position.y=float(source.modules.backdrop.boatBase[1])+(0.0 if backdrop_showcase else .05*sin(time*1.15)+.025*sin(time*2.3+1.3))
  backdrop_motion.boat.position=position
 if backdrop_motion.has("hull"):_backdrop_rotation("hull",.05*sin(time*.9+.4)+.016*sin(time*2.1),backdrop_rest.hull.rotation.y,.02*sin(time*1.3+2))

func advance_backdrop(dt:float)->void:update_backdrop_time(backdrop_time+dt)

func _bind_backdrop_motion()->void:
 var config:Dictionary=source.modules.get("backdrop",{})
 if not config.has("boatBase"):return
 # Pinned dw() fan: five original blades and hub under the unmerged dynamic group.
 var fan_id="f91a4d97-05f6-4f6b-9eab-d156700b99ee"
 assert(source_nodes.has(fan_id),"Source shed fan binding missing")
 var fan:Node3D=source_nodes[fan_id]
 assert(fan.position.is_equal_approx(Vector3(11.95,8.02,-19.5)) and fan.get_child_count()==6,"Source shed fan identity changed")
 backdrop_motion.shed_fan=fan
 for key in ["boat","spreader"]:
  if config.get(key) is Dictionary and source_nodes.has(config[key].get("$node","")):backdrop_motion[key]=source_nodes[config[key]["$node"]]
 if backdrop_motion.has("boat"):
  var id=str(config.boat["$node"])
  for record in source.nodes:
   if record.parent==id and record.type=="Group":backdrop_motion.hull=source_nodes[record.id];break
 if config.get("ship") is Dictionary:
  var id=str(config.ship["$node"])
  for record in source.nodes:
   if record.parent==id and record.type=="Group" and record.userData.get("noMerge",false):backdrop_motion.radar=source_nodes[record.id]
 for key in backdrop_motion:
  var node:Node3D=backdrop_motion[key];node.rotation_order=EULER_ORDER_XYZ
  backdrop_rest[key]={"rotation":node.rotation,"scale":node.scale}
 update_backdrop_time(float(source.get("time",{}).get("t",0)))

func _backdrop_rotation(key:String,x:float,y:float,z:float)->void:
 # Keep source double phase until the final float32 basis, especially radar.
 var a=cos(x);var b=sin(x);var c=cos(y);var d=sin(y);var e=cos(z);var f=sin(z);var scale:Vector3=backdrop_rest[key].scale
 backdrop_motion[key].basis=Basis(Vector3(c*e,a*f+b*e*d,b*f-a*e*d)*scale.x,Vector3(-c*f,a*e-b*f*d,b*e+a*f*d)*scale.y,Vector3(d,-b*c,a*c)*scale.z)

func _backdrop_bounds(geometry:Dictionary)->AABB:
 var positions=_floats(geometry.attributes.position);var orbits=_floats(geometry.attributes.aOrbit);var parameters=_floats(geometry.attributes.aPar);var minimum=Vector3(INF,INF,INF);var maximum=Vector3(-INF,-INF,-INF)
 for vertex in int(geometry.attributes.position.count):
  var center=Vector3(orbits[vertex*4],orbits[vertex*4+1],orbits[vertex*4+2]);var px=positions[vertex*3];var py=positions[vertex*3+1]+60.0;var pz=positions[vertex*3+2];var weight=absf(parameters[vertex*4+3]);var z_bound=absf(pz)*(1.0+.14*weight*.73);var horizontal=absf(orbits[vertex*4+3])+absf(px)+z_bound;var vertical=absf(py)+weight*.73*absf(pz)+.3*z_bound+3.7;var extent=Vector3(horizontal,vertical,horizontal)
  minimum=minimum.min(center-extent);maximum=maximum.max(center+extent)
 return AABB(minimum,maximum-minimum).grow(.01)

func _exit_tree()->void:
 tri_palette.dispose()
