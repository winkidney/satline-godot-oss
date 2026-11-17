extends Node3D

var mode := "pbr"
var seconds := 0.0
var elapsed := 0.0
var frames := 0
var capture := ""
var report_path := ""
var finishing := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--seconds="): seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=")
		elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	assert(mode in ["pbr", "diffuse", "transparency"], "Unknown lab mode")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.09, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.62, 0.72)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 2.0
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 4, 5)
	fill.omni_range = 16
	fill.light_energy = 3.0
	add_child(fill)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2.5, 8.5)
	camera.look_at_from_position(camera.position, Vector3(0, 2.5, 0))
	camera.fov = 45
	camera.make_current()
	match mode:
		"pbr": _setup_pbr()
		"diffuse": _setup_diffuse()
		"transparency": _setup_transparency()
	print("PBR_LAB_READY ", mode)

func _sphere(position: Vector3, material: StandardMaterial3D, label: String) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.7
	mesh.height = 1.4
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	var caption := Label3D.new()
	caption.text = label
	caption.font_size = 32
	caption.pixel_size = 0.006
	caption.position = position + Vector3(0, -0.95, 0)
	caption.modulate = Color(0.9, 0.93, 1)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(caption)

func _material(metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.67, 0.32, 0.12)
	material.metallic = metallic
	material.roughness = roughness
	return material

func _setup_pbr() -> void:
	var entries := [
		[0.0, 0.12, "NONMETAL 0.12"], [0.0, 0.72, "NONMETAL 0.72"],
		[1.0, 0.12, "METAL 0.12"], [1.0, 0.72, "METAL 0.72"],
		[0.0, 0.4, "COAT OFF"], [0.0, 0.4, "COAT ON"],
		[1.0, 0.28, "ANISO OFF"], [1.0, 0.28, "ANISO ON"]]
	for i in entries.size():
		var entry: Array = entries[i]
		var material := _material(entry[0], entry[1])
		if i == 5:
			material.clearcoat_enabled = true
			material.clearcoat = 1.0
			material.clearcoat_roughness = 0.1
		if i == 7:
			material.anisotropy_enabled = true
			material.anisotropy = 0.9
		_sphere(Vector3((i % 4 - 1.5) * 2.0, 3.7 if i < 4 else 1.3, 0), material, entry[2])

func _setup_diffuse() -> void:
	for i in 2:
		var material := _material(0.0, 0.8)
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY if i == 0 else BaseMaterial3D.DIFFUSE_LAMBERT
		_sphere(Vector3(-1.5 if i == 0 else 1.5, 2.5, 0), material, "BURLEY" if i == 0 else "LAMBERT")

func _setup_transparency() -> void:
	var gold := _material(1.0, 0.22)
	_sphere(Vector3(0, 2.5, -1), gold, "OPAQUE OBJECT")
	for i in 2:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = Color(0.15, 0.65, 1.0, 0.48) if i == 0 else Color(1.0, 0.25, 0.15, 0.48)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(3.5, 3.5)
		mesh.material = material
		var layer := MeshInstance3D.new()
		layer.mesh = mesh
		layer.position = Vector3(0, 2.5, 0.5)
		layer.rotation.y = -0.55 if i == 0 else 0.55
		add_child(layer)

func _process(delta: float) -> void:
	frames += 1
	elapsed += delta
	if seconds > 0.0 and elapsed >= seconds and not finishing:
		finishing = true
		_finish.call_deferred()

func _finish() -> void:
	await RenderingServer.frame_post_draw
	if not capture.is_empty():
		assert(get_viewport().get_texture().get_image().save_png(capture) == OK)
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"mode": mode, "engine": Engine.get_version_info(),
			"adapter": RenderingServer.get_video_adapter_name(), "frames": frames,
			"elapsed_seconds": elapsed, "fps": frames / elapsed}, "  "))
	get_tree().quit()
