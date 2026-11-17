extends RefCounted

var source_root: String
var source: Dictionary
var nodes := {}
var geometries := {}
var material_records := {}
var texture_records := {}
var textures := {}
var materials := {}
var meshes := {}
var warnings: Array[String] = []
var wetness := -1.0
var diffuse_mode := BaseMaterial3D.DIFFUSE_BURLEY

func _init(root: String) -> void:
	source_root = root

func file_path(path: String) -> String:
	return source_root.path_join(path.trim_prefix("res://"))

func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(file_path(path), FileAccess.READ)
	assert(file != null, "Missing source data: " + path)
	var data: Variant = JSON.parse_string(file.get_as_text())
	assert(data is Dictionary, "Invalid source data: " + path)
	return data

func load_main() -> void:
	if not source.is_empty():
		return
	source = read_json("res://assets/prepared/scene.json")
	for record in source.nodes:
		nodes[record.id] = record
	for record in source.geometries:
		geometries[record.id] = record
	register_records(source)

func register_records(data: Dictionary) -> void:
	for record in data.get("textures", []):
		texture_records[record.id] = record
	for record in data.get("materials", []):
		material_records[record.id] = record

func transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0], values[1], values[2]), Vector3(values[4], values[5], values[6]), Vector3(values[8], values[9], values[10])), Vector3(values[12], values[13], values[14]))

func floats(attribute: Dictionary) -> PackedFloat32Array:
	return FileAccess.get_file_as_bytes(file_path("res://assets/export/" + str(attribute.file))).to_float32_array()

func texture(reference: Variant) -> Texture2D:
	if not reference is Dictionary or not reference.has("$texture"):
		return null
	var id: String = reference["$texture"]
	if textures.has(id):
		return textures[id]
	if not texture_records.has(id):
		warnings.append("Missing texture record: " + id)
		return null
	var record: Dictionary = texture_records[id]
	var path := str(record.get("godot_source_mip_file", record.get("godot_file", "")))
	if path.is_empty():
		warnings.append("Missing texture data: " + id)
		return null
	var image: Image
	if path.ends_with("miprgba"):
		var raw := FileAccess.get_file_as_bytes(file_path(path))
		image = Image.create_from_data(int(record.width), int(record.height), bool(record.get("godot_has_mipmaps", true)), Image.FORMAT_RGBA8, raw)
	else:
		image = Image.load_from_file(file_path(path))
	if image == null or image.is_empty():
		warnings.append("Cannot decode texture: " + id)
		return null
	var result := ImageTexture.create_from_image(image)
	textures[id] = result
	return result

func material(id: String, has_vertex_color: bool, priority: int = 0) -> StandardMaterial3D:
	var key := id + "|" + str(has_vertex_color) + "|" + str(priority)
	if materials.has(key):
		return materials[key]
	assert(material_records.has(id), "Missing source material: " + id)
	var record: Dictionary = material_records[id]
	var props: Dictionary = record.get("props", {})
	var result := StandardMaterial3D.new()
	var color: Array = props.get("color", [1.0, 1.0, 1.0])
	var base_color := Color(color[0], color[1], color[2], float(props.get("opacity", 1.0)))
	result.metallic = float(props.get("metalness", 0.0))
	result.roughness = float(props.get("roughness", 1.0))
	result.diffuse_mode = diffuse_mode
	if wetness >= 0.0 and record.get("userData", {}).get("sl", {}).has("uSlWet"):
		base_color.r *= lerpf(1.0, 0.8, wetness)
		base_color.g *= lerpf(1.0, 0.8, wetness)
		base_color.b *= lerpf(1.0, 0.8, wetness)
		result.roughness *= lerpf(1.0, 0.5, wetness)
	result.albedo_color = base_color.linear_to_srgb()
	result.vertex_color_use_as_albedo = has_vertex_color and bool(props.get("vertexColors", false))
	result.vertex_color_is_srgb = false
	result.render_priority = clampi(priority, -128, 127)
	result.cull_mode = BaseMaterial3D.CULL_DISABLED if int(props.get("side", 0)) == 2 else BaseMaterial3D.CULL_FRONT if int(props.get("side", 0)) == 1 else BaseMaterial3D.CULL_BACK
	result.albedo_texture = texture(props.get("map"))
	var normal := texture(props.get("normalMap"))
	if normal != null:
		result.normal_enabled = true
		result.normal_texture = normal
		var normal_scale: Array = props.get("normalScale", [1.0, 1.0])
		result.normal_scale = float(normal_scale[0])
	var roughness_map := texture(props.get("roughnessMap"))
	if roughness_map != null:
		result.roughness_texture = roughness_map
		result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	var metallic_map := texture(props.get("metalnessMap"))
	if metallic_map != null:
		result.metallic_texture = metallic_map
		result.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	var ao_map := texture(props.get("aoMap"))
	if ao_map != null:
		result.ao_enabled = true
		result.ao_texture = ao_map
		result.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if props.get("map") is Dictionary:
		var tex_record: Dictionary = texture_records.get(props.map["$texture"], {})
		var repeat: Array = tex_record.get("repeat", [1.0, 1.0])
		var offset: Array = tex_record.get("offset", [0.0, 0.0])
		result.uv1_scale = Vector3(repeat[0], repeat[1], 1.0)
		result.uv1_offset = Vector3(offset[0], offset[1], 0.0)
	var alpha_test := float(props.get("alphaTest", 0.0))
	if alpha_test > 0.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.alpha_scissor_threshold = alpha_test
	elif bool(props.get("transparent", false)) or result.albedo_color.a < 1.0:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if record.get("type") == "MeshBasicMaterial":
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var emission: Array = props.get("emissive", [0.0, 0.0, 0.0])
	if Vector3(emission[0], emission[1], emission[2]).length_squared() > 0.0:
		result.emission_enabled = true
		result.emission = Color(emission[0], emission[1], emission[2]).linear_to_srgb()
		result.emission_energy_multiplier = float(props.get("emissiveIntensity", 1.0))
	materials[key] = result
	return result

func _array3(raw: Variant, stride: int = 3) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(int(raw.size() / stride))
	for i in out.size():
		out[i] = Vector3(raw[i * stride], raw[i * stride + 1], raw[i * stride + 2])
	return out

func _array2(raw: Variant, stride: int = 2) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(int(raw.size() / stride))
	for i in out.size():
		out[i] = Vector2(raw[i * stride], raw[i * stride + 1])
	return out

func _inline_arrays(record: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var attributes: Dictionary = record.attributes
	arrays[Mesh.ARRAY_VERTEX] = _array3(attributes.position, int(record.get("attribute_sizes", {}).get("position", 3)))
	if attributes.has("normal"):
		arrays[Mesh.ARRAY_NORMAL] = _array3(attributes.normal, int(record.get("attribute_sizes", {}).get("normal", 3)))
	if attributes.has("uv"):
		arrays[Mesh.ARRAY_TEX_UV] = _array2(attributes.uv, int(record.get("attribute_sizes", {}).get("uv", 2)))
	if attributes.has("color"):
		var stride := int(record.get("attribute_sizes", {}).get("color", 3))
		var colors := PackedColorArray()
		var raw: Array = attributes.color
		for i in range(0, raw.size(), stride):
			colors.append(Color(raw[i], raw[i + 1], raw[i + 2], raw[i + 3] if stride == 4 else 1.0))
		arrays[Mesh.ARRAY_COLOR] = colors
	return arrays

func _source_arrays(record: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var attributes: Dictionary = record.attributes
	for entry in [["position", Mesh.ARRAY_VERTEX], ["normal", Mesh.ARRAY_NORMAL]]:
		if attributes.has(entry[0]):
			var attribute: Dictionary = attributes[entry[0]]
			arrays[entry[1]] = _array3(floats(attribute), int(attribute.itemSize))
	if attributes.has("uv"):
		var attribute: Dictionary = attributes.uv
		arrays[Mesh.ARRAY_TEX_UV] = _array2(floats(attribute), int(attribute.itemSize))
	if attributes.has("color"):
		var attribute: Dictionary = attributes.color
		var raw := floats(attribute)
		var colors := PackedColorArray()
		for i in range(0, raw.size(), int(attribute.itemSize)):
			colors.append(Color(raw[i], raw[i + 1], raw[i + 2], raw[i + 3] if int(attribute.itemSize) == 4 else 1.0))
		arrays[Mesh.ARRAY_COLOR] = colors
	if attributes.has("skinIndex"):
		var attribute: Dictionary = attributes.skinIndex
		var data := FileAccess.get_file_as_bytes(file_path("res://assets/export/" + str(attribute.file)))
		var bones := PackedInt32Array()
		bones.resize(int(attribute.count) * 4)
		for i in bones.size():
			bones[i] = data.decode_u16(i * 2)
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = floats(attributes.skinWeight)
	if attributes.has("aRest") and attributes.has("aHand"):
		var rest := floats(attributes.aRest)
		var hand := floats(attributes.aHand)
		var colors := PackedColorArray()
		for i in int(attributes.aRest.count):
			var sleeve := rest[i * 4 + 3] > 0.5
			var palm := hand[i * 4 + 2] < -0.06
			colors.append(Color(0.046, 0.068, 0.106) if sleeve else Color(0.33, 0.245, 0.14) if palm else Color(0.15, 0.156, 0.094))
		arrays[Mesh.ARRAY_COLOR] = colors
	return arrays

func build_mesh(geometry: Dictionary, material_ids: Array, inline: bool, priority: int = 0, already_converted: bool = false) -> ArrayMesh:
	var key := str(geometry.id) + "|" + str(material_ids) + "|" + str(priority)
	if meshes.has(key):
		return meshes[key]
	var arrays := _inline_arrays(geometry) if inline else _source_arrays(geometry)
	var indices: PackedInt32Array
	if inline:
		indices = PackedInt32Array(geometry.index)
		if not already_converted:
			for i in range(0, indices.size(), 3):
				var old := indices[i + 1]
				indices[i + 1] = indices[i + 2]
				indices[i + 2] = old
	else:
		indices = FileAccess.get_file_as_bytes(file_path(str(geometry.godot_index))).to_int32_array()
	var groups: Array = geometry.get("groups", []) if material_ids.size() > 1 else []
	if groups.is_empty():
		groups = [{"start": 0, "count": indices.size(), "materialIndex": 0}]
	var result := ArrayMesh.new()
	for group in groups:
		arrays[Mesh.ARRAY_INDEX] = indices.slice(int(group.start), int(group.start + group.count))
		if arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_NORMAL] != null:
			var surface := SurfaceTool.new()
			surface.create_from_arrays(arrays)
			surface.generate_tangents()
			arrays = surface.commit_to_arrays()
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material_id: String = material_ids[int(group.materialIndex)]
		var built := material(material_id, arrays[Mesh.ARRAY_COLOR] != null, priority)
		if geometry.attributes.has("aRest"):
			built = built.duplicate()
			built.albedo_color = Color.WHITE
			built.vertex_color_use_as_albedo = true
			built.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.surface_set_material(result.get_surface_count() - 1, built)
	meshes[key] = result
	return result

func add_mesh(record: Dictionary, geometry: Dictionary, parent: Node3D, inline: bool, pose: Transform3D, converted: bool = false) -> GeometryInstance3D:
	var ids: Array = record.get("materials", [record.get("material")])
	var mesh := build_mesh(geometry, ids, inline, int(record.get("renderOrder", 0)), converted)
	var node: GeometryInstance3D
	if record.has("instanceCount"):
		var multi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = record.has("instanceColor")
		mm.mesh = mesh
		mm.instance_count = int(record.instanceCount)
		for i in mm.instance_count:
			mm.set_instance_transform(i, transform(record.instanceMatrix.slice(i * 16, i * 16 + 16)))
			if mm.use_colors:
				mm.set_instance_color(i, Color(record.instanceColor[i * 3], record.instanceColor[i * 3 + 1], record.instanceColor[i * 3 + 2]))
		multi.multimesh = mm
		node = multi
	else:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		node = instance
	node.name = str(record.get("name", "")) if not str(record.get("name", "")).is_empty() else "SourceMesh"
	node.transform = pose
	node.visible = bool(record.get("visible", true))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(record.get("castShadow", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("source_id", record.get("id", ""))
	parent.add_child(node)
	return node

func add_catalog(kind: String, parent: Node3D) -> Dictionary:
	var data := read_json("res://assets/catalog/" + kind + "/catalog.json")
	register_records(data)
	var catalog_geometries := {}
	for geometry in data.geometries:
		catalog_geometries[geometry.id] = geometry
	for record in data.nodes:
		add_mesh(record, catalog_geometries[record.geometry], parent, true, transform(record.matrix))
	return {"camera": data.camera, "nodes": data.nodes.size(), "materials": data.materials.size(), "textures": data.textures.size()}

func add_source_mesh(id: String, parent: Node3D, pose: Transform3D) -> GeometryInstance3D:
	var record: Dictionary = nodes[id]
	return add_mesh(record, geometries[record.geometry], parent, false, pose)
