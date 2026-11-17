extends SceneTree

const Loader = preload("res://source_loader.gd")

func _initialize() -> void:
	var panorama := Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	for y in 2:
		for x in 4:
			panorama.set_pixel(x, y, Color(float(x + y * 4) / 255.0, 0, 0))
	Loader.orient_panorama(panorama)
	for y in 2:
		for x in 4:
			var source_x := (2 - 1 - x + 4) % 4
			assert(roundi(panorama.get_pixel(x, y).r * 255.0) == source_x + (1 - y) * 4, "Three.js and Godot panorama directions must match")
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("saltline-godot")
	var loader = Loader.new(root)
	var catalog: Dictionary = loader.read_json("res://assets/catalog/render/catalog.json")
	loader.register_records(catalog)
	var selected := {}
	for record in catalog.materials:
		var props: Dictionary = record.props
		if props.get("map") is Dictionary and props.get("roughnessMap") is Dictionary and props.get("metalnessMap") is Dictionary:
			selected = record
			break
	assert(not selected.is_empty(), "Test needs a real packed-ORM material")
	var material: StandardMaterial3D = loader.material(selected.id, false)
	assert(material.albedo_texture != null and material.roughness_texture != null and material.metallic_texture != null)
	assert(material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN)
	assert(material.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE)
	assert(material.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY)
	assert(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	var linear: Array = selected.props.color
	var tint := int(selected.props.get("defines", {}).get("SL_TINT", 0))
	var factor := 1.0
	if selected.userData.get("sl", {}).has("uSlWet"):
		factor -= float(selected.userData.sl.uSlWetP.value[0]) * float(selected.userData.sl.uSlWet.value) * 0.5
	var expected := Color(factor, factor, factor, selected.props.opacity) if tint in [1, 2] else Color(linear[0] * factor, linear[1] * factor, linear[2] * factor, selected.props.opacity)
	assert(material.albedo_color.is_equal_approx(expected.linear_to_srgb()), "Source color and default wetness must be converted for the native material")
	if tint == 1:
		var original := loader.texture(selected.props.map).get_image().get_pixel(0, 0)
		var source_linear := original.srgb_to_linear()
		var baked := material.albedo_texture.get_image().get_pixel(0, 0)
		assert(absf(baked.r - (source_linear.r + linear[0] * original.a)) < 0.003, "Tint 1 must retain the source additive mask")
		assert(is_equal_approx(baked.a, 1.0), "Tint mask must not become surface transparency")
	assert(loader.material(selected.id, false, 0, false).disable_receive_shadows)
	var props_catalog: Dictionary = loader.read_json("res://assets/catalog/props/catalog.json")
	loader.register_records(props_catalog)
	var clamp_id := ""
	for item in props_catalog.materials:
		var map: Variant = item.props.get("map")
		if map is Dictionary and int(loader.texture_records[map["$texture"]].get("wrapS", 1000)) == 1001:
			clamp_id = item.id
			break
	assert(not clamp_id.is_empty() and not loader.material(clamp_id, false).texture_repeat, "Clamp-to-edge textures must not repeat")
	var geometry := {"id": "test-triangle", "attributes": {"position": [0, 0, 0, 1, 0, 0, 0, 1, 0], "normal": [0, 0, 1, 0, 0, 1, 0, 0, 1], "uv": [0, 0, 1, 0, 0, 1]}, "index": [0, 1, 2], "groups": []}
	var mesh: ArrayMesh = loader.build_mesh(geometry, [selected.id], true)
	var arrays := mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 2, 1]), "Three.js catalog winding must be converted once")
	assert(arrays[Mesh.ARRAY_TANGENT].size() == 12, "Native normal mapping needs tangents")
	assert(mesh.surface_get_material(0) is StandardMaterial3D)
	loader.load_main()
	var arm_record: Dictionary = loader.nodes[loader.source.modules.weapon.arms.right.mesh["$node"]]
	var arm_geometry: Dictionary = loader.geometries[arm_record.geometry]
	var arm_mesh: ArrayMesh = loader.build_mesh(arm_geometry, arm_record.materials, false)
	assert(arm_mesh.get_surface_count() > 1, "Arm roughness bins must create native material surfaces")
	var arm_indices := 0
	for i in arm_mesh.get_surface_count():
		arm_indices += arm_mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size()
		assert(arm_mesh.surface_get_material(i) is StandardMaterial3D)
	assert(arm_indices == FileAccess.get_file_as_bytes(loader.file_path(arm_geometry.godot_index)).to_int32_array().size(), "Arm material bins must retain every triangle")
	loader.use_arm_atlas = true
	loader.use_arm_normal = true
	var atlas_mesh: ArrayMesh = loader.build_mesh(arm_geometry, arm_record.materials, false)
	assert(atlas_mesh.get_surface_count() == 1)
	var atlas_arrays := atlas_mesh.surface_get_arrays(0)
	assert(atlas_arrays[Mesh.ARRAY_INDEX].size() == arm_indices and atlas_arrays[Mesh.ARRAY_VERTEX].size() == arm_indices)
	assert(atlas_arrays[Mesh.ARRAY_TEX_UV].size() == arm_indices and atlas_arrays[Mesh.ARRAY_TANGENT].size() == arm_indices * 4)
	assert(atlas_arrays[Mesh.ARRAY_BONES].size() == arm_indices * 4 and atlas_arrays[Mesh.ARRAY_WEIGHTS].size() == arm_indices * 4)
	var atlas_material: StandardMaterial3D = atlas_mesh.surface_get_material(0)
	assert(atlas_material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_ALPHA and atlas_material.normal_enabled)
	assert(loader.warnings.is_empty())
	print("Builtin material and mesh checks passed")
	quit()
