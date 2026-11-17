extends SceneTree

const Loader = preload("res://source_loader.gd")

func _initialize() -> void:
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
	var linear: Array = selected.props.color
	var expected := Color(linear[0], linear[1], linear[2], selected.props.opacity).linear_to_srgb()
	assert(material.albedo_color.is_equal_approx(expected), "Source linear color must be converted for the native material")
	var geometry := {"id": "test-triangle", "attributes": {"position": [0, 0, 0, 1, 0, 0, 0, 1, 0], "normal": [0, 0, 1, 0, 0, 1, 0, 0, 1], "uv": [0, 0, 1, 0, 0, 1]}, "index": [0, 1, 2], "groups": []}
	var mesh: ArrayMesh = loader.build_mesh(geometry, [selected.id], true)
	var arrays := mesh.surface_get_arrays(0)
	assert(arrays[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 2, 1]), "Three.js catalog winding must be converted once")
	assert(arrays[Mesh.ARRAY_TANGENT].size() == 12, "Native normal mapping needs tangents")
	assert(mesh.surface_get_material(0) is StandardMaterial3D)
	assert(loader.warnings.is_empty())
	print("Builtin material and mesh checks passed")
	quit()
