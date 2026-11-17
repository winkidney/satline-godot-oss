extends Node3D

const SCENES := ["mats", "props", "render", "ground", "level", "backdrop", "enemies", "weapon", "hands", "fx"]
const Loader = preload("res://source_loader.gd")

var loader
var camera: Camera3D
var scene_name := "mats"
var capture_path := ""
var report_path := ""
var frame_limit := 0
var time_limit := 0.0
var frame_count := 0
var elapsed := 0.0
var finishing := false
var wetness := -1.0
var lambert := false
var screen_reflection := false
var reflection_selected := false
var report := {"approximation": [], "nodes": 0}

func _ready() -> void:
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
		elif arg.begins_with("--wet="):
			var value := arg.trim_prefix("--wet=")
			assert(value.is_valid_float() and is_finite(float(value)), "Expected a finite wetness value")
			wetness = clampf(float(value), 0.0, 1.0)
		elif arg == "--diffuse=lambert":
			lambert = true
		elif arg == "--ssr":
			screen_reflection = true
			reflection_selected = true
		elif arg == "--no-ssr":
			screen_reflection = false
			reflection_selected = true
	assert(scene_name in SCENES, "Unknown comparison scene: " + scene_name)
	if not reflection_selected:
		screen_reflection = scene_name == "ground"
	var source_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("saltline-godot")
	loader = Loader.new(source_root)
	loader.wetness = wetness
	loader.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT if lambert else BaseMaterial3D.DIFFUSE_BURLEY
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
	var bytes := FileAccess.get_file_as_bytes(loader.file_path("res://assets/export/environment/sky-1.rgba32f"))
	if not bytes.is_empty():
		var image := Image.create_from_data(1024, 512, false, Image.FORMAT_RGBAF, bytes)
		image.flip_y()
		panorama.panorama = ImageTexture.create_from_image(image)
	else:
		push_error("Missing captured sky environment")
	sky.sky_material = panorama
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssr_enabled = screen_reflection
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.42).linear_to_srgb()
	sun.light_energy = 3.0
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at(-Vector3(0.91634736, 0.22508532, 0.33112552), Vector3.UP)
	report.approximation.append("Captured static lighting panorama also supplies the visible sky; source uses a separate dynamic sky")
	report.approximation.append("Native lighting, shadows and tone mapping differ from the source renderer")

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.near = 0.08
	camera.far = 900.0
	camera.fov = 74.0
	add_child(camera)
	camera.make_current()

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
		_add_rain()
		report.approximation.append("Flat native water, simple wet ground and native particle rain replace the source wave, wetness and rain shaders")
	else:
		_floor()
		report.approximation.append("Native standard materials omit source procedural wetness and triplanar patches")

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
	report.approximation.append("Hand uses source open-palm bone pose and simple vertex color regions; source stitch, fabric and rain are omitted")

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
	var smoke := GPUParticles3D.new()
	smoke.amount = 50
	smoke.lifetime = 2.0
	smoke.position = sparks.position
	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = Vector3.UP
	smoke_process.spread = 45.0
	smoke_process.initial_velocity_min = 0.4
	smoke_process.initial_velocity_max = 1.0
	smoke_process.gravity = Vector3(0, 0.3, 0)
	smoke_process.scale_min = 0.4
	smoke_process.scale_max = 0.8
	smoke.process_material = smoke_process
	var smoke_mesh := QuadMesh.new()
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.25, 0.25, 0.25, 0.28), Color(0.25, 0.25, 0.25, 0.0)])
	var soft_circle := GradientTexture2D.new()
	soft_circle.gradient = gradient
	soft_circle.fill = GradientTexture2D.FILL_RADIAL
	soft_circle.fill_from = Vector2(0.5, 0.5)
	soft_circle.fill_to = Vector2(1.0, 0.5)
	smoke_material.albedo_texture = soft_circle
	smoke_mesh.material = smoke_material
	smoke.draw_pass_1 = smoke_mesh
	add_child(smoke)
	smoke.emitting = true
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
	rain.amount = 1600
	rain.lifetime = 1.0
	rain.preprocess = 1.0
	rain.position = camera.position + Vector3(0, 8, 0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(12, 5, 12)
	process.direction = Vector3.DOWN
	process.spread = 2.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 20.0
	process.gravity = Vector3(0, -5, 0)
	rain.process_material = process
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.45, 0.012)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.65, 0.75, 0.85, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = material
	rain.draw_pass_1 = drop
	add_child(rain)
	rain.emitting = true

func _process(delta: float) -> void:
	frame_count += 1
	elapsed += delta
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
