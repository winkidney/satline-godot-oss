extends Node3D

const SCENES := ["mats", "props", "render", "ground", "level", "backdrop", "enemies", "weapon", "hands", "fx"]
# Source auto-exposure captured near five seconds in each showcase.
const SOURCE_EXPOSURE := {"mats": 0.755, "props": 0.666, "render": 0.696, "ground": 0.6,
	"level": 0.624, "backdrop": 0.6, "enemies": 0.671, "weapon": 0.706, "hands": 0.6, "fx": 0.627}
const Loader = preload("res://source_loader.gd")

var loader
var camera: Camera3D
var sky_background: MeshInstance3D
var smoke_cards: Array[Sprite3D] = []
var flash_cards: Array[MeshInstance3D] = []
var scene_name := "mats"
var capture_path := ""
var report_path := ""
var frame_limit := 0
var time_limit := 0.0
var frame_count := 0
var elapsed := 0.0
var finishing := false
var wetness := -1.0
var lambert := true
var screen_reflection := false
var reflection_selected := false
var report := {"approximation": [], "nodes": 0}
var calibration := {"sun_energy": 9.0 / PI, "sky_index": 1, "sky_rotation": 0.0, "separate_background": 1,
	"sky_red": 1.2, "sky_green": 1.05, "sky_blue": 0.9,
	"background_energy": 1.45, "ambient_energy": 1.0, "exposure": 1.0, "white": 14.26024,
	"tonemap": "aces", "brightness": 1.0, "contrast": 1.0, "saturation": 1.0,
	"fog_density": 0.0, "volumetric_density": 0.005, "volumetric_anisotropy": 0.2, "glow_intensity": 0.3,
	"ssao_intensity": 8.0, "ssao_radius": 0.5, "ssao_power": 1.5,
	"ssao_light_affect": 1.0, "ssao_ao_channel_affect": 1.0, "ssao_horizon": 0.06, "sun_angular_distance": 2.0, "source_grade": 2,
	"arm_atlas": 1, "arm_normal": 0, "arm_normal_strength": 1.0,
	"ground_atlas": 1, "ground_normal_strength": 1.0, "ground_specular": 0.25, "ground_albedo": 2.0}

func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		set_process(false)
		get_tree().quit(1)
	return condition

func _ready() -> void:
	var supplied := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_name = arg.trim_prefix("--scene=")
		elif arg.begins_with("--frames="):
			frame_limit = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--seconds="):
			time_limit = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--calibration="):
			var file := FileAccess.open(arg.trim_prefix("--calibration="), FileAccess.READ)
			if not _require(file != null, "Missing calibration settings"): return
			var settings: Variant = JSON.parse_string(file.get_as_text())
			if not _require(settings is Dictionary, "Calibration must be an object"): return
			for key in settings:
				if not _require(calibration.has(key), "Unknown calibration setting: " + str(key)): return
				if key != "tonemap":
					if not _require((settings[key] is float or settings[key] is int) and is_finite(float(settings[key])), "Invalid calibration value: " + str(key)): return
				calibration[key] = settings[key]
				supplied[key] = true
		elif arg.begins_with("--wet="):
			var value := arg.trim_prefix("--wet=")
			if not _require(value.is_valid_float() and is_finite(float(value)), "Expected a finite wetness value"): return
			wetness = clampf(float(value), 0.0, 1.0)
		elif arg == "--diffuse=lambert":
			lambert = true
		elif arg == "--diffuse=burley":
			lambert = false
		elif arg == "--ssr":
			screen_reflection = true
			reflection_selected = true
		elif arg == "--no-ssr":
			screen_reflection = false
			reflection_selected = true
	if not _require(scene_name in SCENES, "Unknown comparison scene: " + scene_name): return
	if not supplied.has("exposure"):
		calibration.exposure = float(SOURCE_EXPOSURE[scene_name]) * 1.3 / 1.8
	if scene_name == "ground" and not supplied.has("ssao_intensity"):
		calibration.ssao_intensity = 1.0
	if not supplied.has("volumetric_density"):
		calibration.volumetric_density = {"level": 0.04, "ground": 0.02, "render": 0.0, "enemies": 0.0, "weapon": 0.0}.get(scene_name, 0.005)
	if not supplied.has("glow_intensity"):
		calibration.glow_intensity = 0.7 if scene_name in ["level", "ground"] else 0.0 if scene_name in ["render", "enemies", "weapon"] else 0.3
	if not _require(float(calibration.sky_index) == 0.0 or float(calibration.sky_index) == 1.0, "Expected source sky 0 or 1"): return
	if not _require(calibration.tonemap in ["linear", "reinhard", "filmic", "aces", "agx"], "Unknown tone mapper"): return
	for flag in ["separate_background", "arm_atlas", "arm_normal", "ground_atlas"]:
		if not _require(float(calibration[flag]) == 0.0 or float(calibration[flag]) == 1.0, "Expected a boolean calibration flag: " + flag): return
	if not _require(float(calibration.source_grade) == 0.0 or float(calibration.source_grade) == 1.0 or float(calibration.source_grade) == 2.0, "Unknown color grade"): return
	if not _require(calibration.exposure > 0.0 and calibration.white > 0.0 and calibration.ssao_radius > 0.0, "Exposure, white and SSAO radius must be positive"): return
	if not _require(calibration.ssao_intensity >= 0.0 and calibration.sun_energy >= 0.0 and calibration.background_energy >= 0.0, "Lighting strengths must be nonnegative"): return
	if not _require(calibration.ssao_power > 0.0 and calibration.ssao_horizon >= 0.0 and calibration.ssao_horizon <= 1.0, "Invalid SSAO settings"): return
	if not _require(calibration.volumetric_density >= 0.0 and calibration.glow_intensity >= 0.0 and absf(calibration.volumetric_anisotropy) <= 1.0, "Invalid atmosphere settings"): return
	if not _require(calibration.ssao_light_affect >= 0.0 and calibration.ssao_light_affect <= 1.0 and calibration.ssao_ao_channel_affect >= 0.0 and calibration.ssao_ao_channel_affect <= 1.0, "SSAO influence must be between 0 and 1"): return
	if not _require(calibration.ground_specular >= 0.0 and calibration.ground_specular <= 1.0 and calibration.ground_albedo >= 0.0, "Invalid ground material"): return
	if not _require(calibration.arm_normal_strength >= 0.0 and calibration.ground_normal_strength >= 0.0, "Normal strength must be nonnegative"): return
	if not reflection_selected:
		screen_reflection = scene_name == "ground"
	var source_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("saltline-godot")
	loader = Loader.new(source_root)
	loader.wetness = wetness
	loader.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if lambert else BaseMaterial3D.DIFFUSE_BURLEY
	loader.use_arm_atlas = int(calibration.arm_atlas) == 1
	loader.use_arm_normal = int(calibration.arm_normal) == 1
	loader.arm_normal_strength = float(calibration.arm_normal_strength)
	_setup_environment()
	_setup_camera()
	match scene_name:
		"mats", "props", "render", "ground":
			_setup_catalog()
		"level", "backdrop":
			_setup_level()
		"enemies":
			_setup_enemies()
		"weapon":
			_setup_weapon()
		"hands":
			_setup_hands()
		"fx":
			_setup_fx()
	print("BUILTIN_READY ", JSON.stringify({"scene": scene_name, "engine": Engine.get_version_info(), "nodes": report.nodes}))

func _setup_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	var bytes := FileAccess.get_file_as_bytes(loader.file_path("res://assets/export/environment/sky-%d.rgba32f" % int(calibration.sky_index)))
	if not bytes.is_empty():
		var image := Image.create_from_data(1024, 512, false, Image.FORMAT_RGBAF, bytes)
		Loader.orient_panorama(image)
		panorama.panorama = ImageTexture.create_from_image(image)
	else:
		push_error("Missing captured sky environment")
	sky.sky_material = panorama
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.sky_rotation.y = deg_to_rad(float(calibration.sky_rotation))
	env.background_energy_multiplier = float(calibration.background_energy)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(calibration.ambient_energy)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = {"linear": Environment.TONE_MAPPER_LINEAR, "reinhard": Environment.TONE_MAPPER_REINHARDT,
		"filmic": Environment.TONE_MAPPER_FILMIC, "aces": Environment.TONE_MAPPER_ACES, "agx": Environment.TONE_MAPPER_AGX}[calibration.tonemap]
	env.tonemap_exposure = float(calibration.exposure)
	env.tonemap_white = float(calibration.white)
	env.adjustment_enabled = true
	env.adjustment_brightness = float(calibration.brightness)
	env.adjustment_contrast = float(calibration.contrast)
	env.adjustment_saturation = float(calibration.saturation)
	if int(calibration.source_grade) in [1, 2]:
		env.adjustment_color_correction = preload("res://native_grade.gd").create_texture(int(calibration.source_grade))
	env.fog_enabled = float(calibration.fog_density) > 0.0
	env.fog_density = float(calibration.fog_density)
	env.volumetric_fog_enabled = float(calibration.volumetric_density) > 0.0
	env.volumetric_fog_density = float(calibration.volumetric_density)
	env.volumetric_fog_anisotropy = float(calibration.volumetric_anisotropy)
	env.volumetric_fog_length = 120.0
	env.glow_enabled = float(calibration.glow_intensity) > 0.0
	env.glow_intensity = float(calibration.glow_intensity)
	env.ssao_enabled = float(calibration.ssao_intensity) > 0.0
	env.ssao_intensity = float(calibration.ssao_intensity)
	env.ssao_radius = float(calibration.ssao_radius)
	env.ssao_power = float(calibration.ssao_power)
	env.ssao_light_affect = float(calibration.ssao_light_affect)
	env.ssao_ao_channel_affect = float(calibration.ssao_ao_channel_affect)
	env.ssao_horizon = float(calibration.ssao_horizon)
	env.ssr_enabled = screen_reflection
	if int(calibration.separate_background) == 1:
		var background_bytes := FileAccess.get_file_as_bytes(loader.file_path("res://assets/export/environment/sky-0.rgba32f"))
		assert(not background_bytes.is_empty(), "Missing source background panorama")
		var background_image := Image.create_from_data(1024, 512, false, Image.FORMAT_RGBAF, background_bytes)
		background_image.flip_y()
		var background_material := StandardMaterial3D.new()
		background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		background_material.cull_mode = BaseMaterial3D.CULL_FRONT
		background_material.disable_fog = true
		background_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		# Draw the transparent background before rain and smoke, which have the same camera depth.
		background_material.render_priority = -128
		background_material.albedo_color = Color(float(calibration.sky_red), float(calibration.sky_green), float(calibration.sky_blue)).linear_to_srgb()
		background_material.albedo_texture = ImageTexture.create_from_image(background_image)
		var sphere := SphereMesh.new()
		sphere.radius = 700.0
		sphere.height = 1400.0
		sphere.radial_segments = 128
		sphere.rings = 64
		sphere.material = background_material
		sky_background = MeshInstance3D.new()
		sky_background.mesh = sphere
		sky_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sky_background)
		env.background_mode = Environment.BG_COLOR
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.42).linear_to_srgb()
	sun.light_energy = float(calibration.sun_energy)
	sun.light_angular_distance = float(calibration.sun_angular_distance)
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at(-Vector3(0.91634736, 0.22508532, 0.33112552), Vector3.UP)
	report.approximation.append("Captured static background and lighting panoramas approximate the source dynamic sky" if sky_background != null else "Captured static lighting panorama also supplies the visible sky; source uses a separate dynamic sky")
	report.approximation.append("Native lighting, shadows and tone mapping differ from the source renderer")

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.near = 0.08
	camera.far = 900.0
	camera.fov = 74.0
	add_child(camera)
	camera.make_current()
	if sky_background != null:
		sky_background.position = camera.position

func _camera_from(record: Dictionary) -> void:
	var p: Array = record.position
	var q: Array = record.quaternion
	camera.position = Vector3(p[0], p[1], p[2])
	camera.quaternion = Quaternion(q[0], q[1], q[2], q[3]).normalized()
	camera.fov = float(record.get("fov", 74.0))
	camera.near = float(record.get("near", 0.08))
	camera.far = float(record.get("far", 900.0))

func _floor() -> void:
	loader.load_main()
	var geometry: Dictionary = loader.read_json("res://assets/export/fx-showcase-geometry.json").ground
	geometry["id"] = "common-showcase-ground"
	for entry in loader.source.materials:
		if entry.name == "concrete":
			var record := {"id": geometry.id, "name": "ShowcaseGround", "materials": [entry.id], "visible": true, "castShadow": false}
			loader.add_mesh(record, geometry, self, true, Transform3D.IDENTITY, true)
			return
	push_error("Missing source concrete material for showcase ground")

func _setup_catalog() -> void:
	var kind := "materials-full" if scene_name == "mats" else scene_name
	var data: Dictionary = loader.add_catalog(kind, self)
	_camera_from(data.camera)
	report.nodes = data.nodes
	report["catalog"] = data
	if scene_name == "ground":
		loader.load_main()
		for source_node in loader.source.nodes:
			if source_node.name not in ["apron", "sea", "quaySkirt"] or not source_node.has("geometry"):
				continue
			var node: GeometryInstance3D = loader.add_source_mesh(source_node.id, self, loader.transform(source_node.matrixWorld))
			var approximation := StandardMaterial3D.new()
			var wet := maxf(wetness, 1.0 if wetness < 0.0 else 0.0)
			approximation.albedo_color = Color(0.08, 0.16, 0.22) if source_node.name == "sea" else Color(0.24, 0.25, 0.26).lerp(Color(0.14, 0.15, 0.16), wet)
			approximation.roughness = 0.18 if source_node.name == "sea" else lerpf(0.72, 0.28, wet)
			node.material_override = approximation
			report.nodes += 1
		var baked_ground := int(calibration.ground_atlas) == 1 and (wetness < 0.0 or wetness >= 0.95)
		if baked_ground:
			_add_ground_atlas()
		_add_rain()
		report.approximation.append("Native water and particle rain approximate the source; baked ground is one fixed weather and camera state" if baked_ground else "Flat native water, simple wet ground and native particle rain replace the source wave, wetness and rain shaders")
	else:
		_floor()
		report.approximation.append("Native standard materials omit source procedural wetness and triplanar patches")

func _add_ground_atlas() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-16, 0.002, 40), Vector3(30, 0.002, 40), Vector3(-16, 0.002, -32), Vector3(30, 0.002, -32)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
	for i in [0, 1, 2, 1, 3, 2]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[i])
		surface.add_vertex(points[i])
	surface.generate_tangents()
	var material := StandardMaterial3D.new()
	material.diffuse_mode = loader.diffuse_mode
	var albedo_factor := float(calibration.ground_albedo)
	material.albedo_color = Color(albedo_factor, albedo_factor, albedo_factor).linear_to_srgb()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_repeat = false
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var color_bytes := FileAccess.get_file_as_bytes("res://assets/baked-ground/color-roughness.rgba8")
	assert(color_bytes.size() == 2048 * 2048 * 4, "Missing baked ground color")
	var color := Image.create_from_data(2048, 2048, false, Image.FORMAT_RGBA8, color_bytes)
	color.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(color)
	material.roughness = 1.0
	var rough_bytes := FileAccess.get_file_as_bytes("res://assets/baked-ground/roughness.r8")
	assert(rough_bytes.size() == 2048 * 2048, "Missing calibrated ground roughness")
	var rough := Image.create_from_data(2048, 2048, false, Image.FORMAT_R8, rough_bytes)
	rough.generate_mipmaps()
	material.roughness_texture = ImageTexture.create_from_image(rough)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic_specular = float(calibration.ground_specular)
	if float(calibration.ground_normal_strength) > 0.0:
		var normal_bytes := FileAccess.get_file_as_bytes("res://assets/baked-ground/normal.rgba8")
		assert(normal_bytes.size() == 2048 * 2048 * 4, "Missing baked ground normal")
		var normal := Image.create_from_data(2048, 2048, false, Image.FORMAT_RGBA8, normal_bytes)
		normal.generate_mipmaps()
		material.normal_enabled = true
		material.normal_scale = float(calibration.ground_normal_strength)
		material.normal_texture = ImageTexture.create_from_image(normal)
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _setup_level() -> void:
	loader.load_main()
	var fixture_name := "level-showcase-bindings.json" if scene_name == "level" else "backdrop-all-showcase-bindings.json"
	var fixture: Dictionary = loader.read_json("res://assets/export/" + fixture_name)
	_camera_from(fixture.camera)
	_floor()
	for binding in fixture.nodes:
		var record: Dictionary = loader.nodes[binding.id]
		loader.add_source_mesh(record.id, self, loader.transform(record.matrixWorld))
		report.nodes += 1
	for extra in fixture.get("extras", []):
		var record := {"id": extra.geometry.id, "name": "BackdropLabel", "materials": extra.materials, "visible": true, "castShadow": false}
		var node: GeometryInstance3D = loader.add_mesh(record, extra.geometry, self, false, loader.transform(extra.matrix))
		if extra.has("label_texture"):
			var image_record: Dictionary = extra.label_texture
			var image := Image.create_from_data(int(image_record.width), int(image_record.height), true, Image.FORMAT_RGBA8, FileAccess.get_file_as_bytes(loader.file_path(image_record.file)))
			var replacement: StandardMaterial3D = loader.material(extra.materials[0], false).duplicate()
			replacement.albedo_texture = ImageTexture.create_from_image(image)
			node.material_override = replacement
		report.nodes += 1
	if scene_name == "level":
		for record in loader.source.nodes:
			if record.type != "PointLight" or loader.nodes.get(record.parent, {}).get("name", "") != "level-dynamic":
				continue
			var light := OmniLight3D.new()
			light.position = loader.transform(record.matrixWorld).origin
			var c: Array = record.light.color
			light.light_color = Color(c[0], c[1], c[2]).linear_to_srgb()
			light.light_energy = float(record.light.intensity) / PI
			light.omni_range = float(record.light.distance)
			light.shadow_enabled = bool(record.castShadow)
			add_child(light)
	else:
		report.approximation.append("Backdrop uses exported pose; source procedural sky, birds and boat animation are not reproduced")

func _skin_actor(mesh_id: String, parent: Node3D, bone_overrides: Dictionary) -> void:
	var record: Dictionary = loader.nodes[mesh_id]
	var instance: MeshInstance3D = loader.add_source_mesh(mesh_id, parent, Transform3D.IDENTITY)
	var skin_record: Dictionary = record.skin
	var skeleton := Skeleton3D.new()
	parent.add_child(skeleton)
	for id in skin_record.bones:
		var bone: Dictionary = loader.nodes[id]
		skeleton.add_bone(str(bone.name) if not str(bone.name).is_empty() else "bone_" + str(skeleton.get_bone_count()))
	var skin := Skin.new()
	for i in skin_record.bones.size():
		var id: String = skin_record.bones[i]
		var bone: Dictionary = loader.nodes[id]
		var bone_parent: int = skin_record.bones.find(bone.parent)
		skeleton.set_bone_parent(i, bone_parent)
		var rest: Transform3D = loader.transform(skin_record.boneInverses[i]).affine_inverse()
		if bone_parent >= 0:
			rest = loader.transform(skin_record.boneInverses[bone_parent]) * rest
		skeleton.set_bone_rest(i, rest)
		skeleton.set_bone_pose(i, bone_overrides.get(id, loader.transform(bone.matrix)))
		skin.add_bind(i, loader.transform(skin_record.boneInverses[i]))
	instance.skeleton = instance.get_path_to(skeleton)
	instance.skin = skin
	report.nodes += 1

func _setup_enemies() -> void:
	loader.load_main()
	var reference: Dictionary = loader.read_json("res://assets/export/enemies-showcase-reference.json").both
	_camera_from(reference.camera)
	_floor()
	for actor in reference.enemies.actors:
		var kind: String = actor.state.type
		var rig: Dictionary = loader.source.modules.enemies.debug.gulls[0].rig if kind == "gull" else loader.source.modules.enemies.debug.hounds[0].rig
		var overrides := {}
		for bone_name in rig.bones:
			if actor.bones.has(bone_name):
				overrides[rig.bones[bone_name]["$node"]] = loader.transform(actor.bones[bone_name].matrix)
		var group := Node3D.new()
		group.transform = loader.transform(actor.group)
		add_child(group)
		_skin_actor(rig.mesh["$node"], group, overrides)
	report.approximation.append("Enemy geometry and stored poses are retained; movement and attack effects are not reproduced")

func _setup_weapon() -> void:
	loader.load_main()
	_floor()
	var rig: Dictionary = loader.source.modules.weapon.rigs.rifle
	var root_record: Dictionary = loader.nodes[rig.root["$node"]]
	var mount := Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.25, 0))
	for record in loader.source.nodes:
		if not record.has("geometry") or not _descends_from(record, root_record.id):
			continue
		var relative: Transform3D = loader.transform(root_record.matrixWorld).affine_inverse() * loader.transform(record.matrixWorld)
		loader.add_source_mesh(record.id, self, mount * relative)
		report.nodes += 1
	var arms := Node3D.new()
	arms.transform = mount
	add_child(arms)
	var snapshot: Dictionary = loader.read_json("res://evidence/weapon-studio-rifle-side-source-triangle-confirm.json")
	for side in ["right", "left"]:
		var arm: Dictionary = loader.source.modules.weapon.arms[side]
		var overrides := {}
		for bone_ref in arm.bones:
			var id: String = bone_ref["$node"]
			for pose in snapshot.bones:
				if pose.side == "arm-" + side and pose.name == loader.nodes[id].name:
					var p: Array = pose.p
					var q: Array = pose.q
					overrides[id] = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])), Vector3(p[0], p[1], p[2]))
					break
		_skin_actor(arm.mesh["$node"], arms, overrides)
	var view: Array = loader.read_json("res://assets/export/weapon-showcase-views.json").rifle.side
	camera.position = Vector3(view[1][0], view[1][1], view[1][2])
	camera.look_at(Vector3(view[2][0], view[2][1], view[2][2]))
	camera.fov = float(view[3])
	report.approximation.append("Weapon and hand meshes use a stored source pose; procedural wear and hand animation are omitted")

func _descends_from(record: Dictionary, ancestor: String) -> bool:
	var id: Variant = record.id
	while id != null and loader.nodes.has(id):
		if id == ancestor:
			return true
		id = loader.nodes[id].parent
	return false

func _setup_hands() -> void:
	loader.load_main()
	_floor()
	var studio := Node3D.new()
	studio.position = Vector3(0, 1.16, 0)
	studio.basis = Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.BACK, PI)
	add_child(studio)
	var config: Dictionary = loader.read_json("res://assets/export/weapon-arm-pose-config.json")
	var pose: Array = loader.read_json("res://assets/export/hands-showcase-poses.json").open
	for side in ["right", "left"]:
		var arm: Dictionary = loader.source.modules.weapon.arms[side]
		var model = preload("res://scripts/weapon_arm_pose.gd").new(config, side == "left")
		model.bones[0].p = [0.125 if side == "right" else -0.125, 0.0, 0.57]
		for i in 5:
			model.bones[i].q = [0.0, 0.0, 0.0, 1.0]
		model.set_fingers(pose)
		var overrides := {}
		for i in arm.bones.size():
			var p: Array = model.bones[i].p
			var q: Array = model.bones[i].q
			overrides[arm.bones[i]["$node"]] = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])), Vector3(p[0], p[1], p[2]))
		_skin_actor(arm.mesh["$node"], studio, overrides)
	camera.position = Vector3(0.2, 1.34, 0.78)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.fov = 26.0
	report.approximation.append("Hand uses a source pose and offline-baked surface; dynamic stitch, wetness and rain remain approximate" if int(calibration.arm_atlas) == 1 else "Hand uses a source pose and simplified vertex colors; stitch, fabric and rain are omitted")

func _setup_fx() -> void:
	loader.load_main()
	_floor()
	camera.position = Vector3(0.3, 1.6, 7.2)
	camera.look_at(Vector3(0.2, 1, 0))
	var sparks := GPUParticles3D.new()
	sparks.amount = 96
	sparks.lifetime = 1.2
	sparks.position = Vector3(0, 1.3, 0)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.spread = 70.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 5.0
	process.gravity = Vector3(0, -7, 0)
	sparks.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.05
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.5, 0.08)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.3, 0.03)
	glow.emission_energy_multiplier = 3.0
	mesh.material = glow
	sparks.draw_pass_1 = mesh
	add_child(sparks)
	sparks.emitting = true
	var light := OmniLight3D.new()
	light.position = sparks.position
	light.light_color = Color(1.0, 0.28, 0.04)
	light.light_energy = 2.0
	light.omni_range = 5.0
	add_child(light)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var smoke_textures: Array[ImageTexture] = []
	for variant in 3:
		noise.seed = 31 + variant * 71
		var smoke_image := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var radius := Vector2(float(x) / 64.0 - 1.0, float(y) / 64.0 - 1.0).length()
				var edge := clampf((1.0 - radius) * 3.0, 0.0, 1.0)
				var density := clampf(0.65 + noise.get_noise_2d(x, y), 0.1, 1.0)
				smoke_image.set_pixel(x, y, Color(0.18, 0.17, 0.16, edge * density * 0.9))
		smoke_textures.append(ImageTexture.create_from_image(smoke_image))
	for i in 12:
		var card := Sprite3D.new()
		card.texture = smoke_textures[i % smoke_textures.size()]
		card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		card.pixel_size = 0.01 + 0.002 * float(i % 3)
		add_child(card)
		smoke_cards.append(card)
	var flash_gradient := Gradient.new()
	flash_gradient.colors = PackedColorArray([Color(1.0, 1.0, 0.8, 1.0), Color(1.0, 0.2, 0.02, 0.0)])
	var flash_texture := GradientTexture2D.new()
	flash_texture.gradient = flash_gradient
	flash_texture.fill = GradientTexture2D.FILL_RADIAL
	flash_texture.fill_from = Vector2(0.5, 0.5)
	flash_texture.fill_to = Vector2(1.0, 0.5)
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flash_material.albedo_texture = flash_texture
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.55, 0.2)
	flash_material.emission_energy_multiplier = 8.0
	flash_material.emission_texture = flash_texture
	var flash_mesh := QuadMesh.new()
	flash_mesh.size = Vector2(0.55, 0.55)
	flash_mesh.material = flash_material
	for p in [Vector3(0.1, 1.35, 0.65), Vector3(5.0, 0.75, 1.0)]:
		var flash := MeshInstance3D.new()
		flash.mesh = flash_mesh
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.position = p
		add_child(flash)
		flash_cards.append(flash)
	var fire_light := OmniLight3D.new()
	fire_light.position = Vector3(5.0, 0.75, 1.0)
	fire_light.light_color = Color(1.0, 0.35, 0.08)
	fire_light.light_energy = 2.0
	fire_light.omni_range = 3.0
	add_child(fire_light)
	var tracers := GPUParticles3D.new()
	tracers.amount = 6
	tracers.lifetime = 0.45
	tracers.preprocess = 0.45
	tracers.position = Vector3(3.8, 1.55, 0.5)
	tracers.visibility_aabb = AABB(Vector3(-8, -2, -2), Vector3(16, 4, 4))
	var tracer_process := ParticleProcessMaterial.new()
	tracer_process.direction = Vector3.LEFT
	tracer_process.spread = 1.0
	tracer_process.initial_velocity_min = 12.0
	tracer_process.initial_velocity_max = 16.0
	tracer_process.gravity = Vector3.ZERO
	tracers.process_material = tracer_process
	var streak := BoxMesh.new()
	streak.size = Vector3(0.8, 0.012, 0.012)
	var tracer_material := StandardMaterial3D.new()
	tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_material.albedo_color = Color(1.0, 0.75, 0.38)
	tracer_material.emission_enabled = true
	tracer_material.emission = Color(1.0, 0.55, 0.18)
	tracer_material.emission_energy_multiplier = 4.0
	streak.material = tracer_material
	tracers.draw_pass_1 = streak
	add_child(tracers)
	tracers.emitting = true
	var geometry: Dictionary = loader.read_json("res://assets/export/fx-showcase-geometry.json")
	for i in geometry.objects.size():
		var object: Dictionary = geometry.objects[i]
		var material_id := ""
		for entry in loader.source.materials:
			if entry.name == object.material:
				material_id = entry.id
				break
		assert(not material_id.is_empty(), "Missing source FX surface material: " + str(object.material))
		object["id"] = "fx-object-" + str(i)
		var record := {"id": object.id, "name": object.surface, "materials": [material_id], "visible": true, "castShadow": true}
		var position: Array = object.position
		loader.add_mesh(record, object, self, true, Transform3D(Basis.IDENTITY, Vector3(position[0], position[1], position[2])), true)
		report.nodes += 1
	report.approximation.append("Built-in particles and simple lighting replace source tracer, sparks, smoke and explosion shaders")

func _add_rain() -> void:
	var rain := GPUParticles3D.new()
	rain.amount = 2500
	rain.lifetime = 1.0
	rain.preprocess = 1.0
	rain.position = camera.position + Vector3(0, 8, 0)
	rain.visibility_aabb = AABB(Vector3(-24, -30, -24), Vector3(48, 50, 48))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12, 5, 12)
	process.direction = Vector3(0.12, -1.0, -0.1).normalized()
	process.spread = 2.0
	process.angle_min = -7.0
	process.angle_max = -4.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -5, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.005, 0.4, 0.005)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.87, 0.8, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = material
	rain.draw_pass_1 = drop
	add_child(rain)
	rain.emitting = true

func _process(delta: float) -> void:
	if sky_background != null:
		sky_background.position = camera.position
	frame_count += 1
	elapsed += delta
	for i in smoke_cards.size():
		var phase := fposmod(elapsed * 0.55 + float(i) * 0.31, 3.0)
		var card := smoke_cards[i]
		card.position = Vector3(3.5 + sin(float(i) * 2.4) * 1.35 + phase * 0.1,
			1.7 + phase * 0.55 + sin(float(i) * 3.7) * 0.2, 0.5 + float(i % 3) * 0.1)
		card.modulate.a = sin(PI * phase / 3.0) * 0.9
	for i in flash_cards.size():
		flash_cards[i].scale = Vector3.ONE * (0.65 + 0.35 * absf(sin(elapsed * (6.0 + float(i)) + float(i))))
	if not finishing and ((frame_limit > 0 and frame_count >= frame_limit) or (time_limit > 0.0 and elapsed >= time_limit)):
		finishing = true
		_finish.call_deferred()

func _finish() -> void:
	await RenderingServer.frame_post_draw
	if not capture_path.is_empty():
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		assert(error == OK, "Cannot save capture")
	report["scene"] = scene_name
	report["engine"] = Engine.get_version_info()
	report["rendering_method"] = RenderingServer.get_current_rendering_method()
	report["video_adapter"] = RenderingServer.get_video_adapter_name()
	report["diffuse_mode"] = "lambert" if lambert else "burley"
	report["wet_approximation"] = wetness if wetness >= 0.0 else null
	report["screen_space_reflection"] = screen_reflection
	report["calibration"] = calibration
	report["frames"] = frame_count
	report["elapsed_seconds"] = elapsed
	report["fps"] = frame_count / elapsed if elapsed > 0.0 else 0.0
	report["camera"] = {"position": [camera.position.x, camera.position.y, camera.position.z], "quaternion": [camera.quaternion.x, camera.quaternion.y, camera.quaternion.z, camera.quaternion.w], "fov": camera.fov}
	report["material_count"] = loader.materials.size()
	report["texture_count"] = loader.textures.size()
	report["warnings"] = loader.warnings
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		assert(file != null, "Cannot write comparison report")
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("BUILTIN_REPORT ", JSON.stringify(report))
	get_tree().quit()
