extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0, 3)
	camera.make_current()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var quad := MeshInstance3D.new()
	quad.mesh = mesh
	world.add_child(quad)
	material.albedo_color = Color(0.18, 0.18, 0.18).linear_to_srgb()
	var gray := await _sample()
	var gray_expected := Color(0.18, 0.18, 0.18).linear_to_srgb().r
	assert(absf(gray.r - gray_expected) < 0.015, "Linear gray card must reach the expected sRGB value")
	var hdr := Image.create_empty(1, 1, false, Image.FORMAT_RGBAH)
	hdr.set_pixel(0, 0, Color(2, 2, 2, 1))
	material.albedo_color = Color.WHITE
	material.albedo_texture = ImageTexture.create_from_image(hdr)
	environment.environment.tonemap_exposure = 0.25
	var hdr_sample := await _sample()
	var hdr_expected := Color(0.5, 0.5, 0.5).linear_to_srgb().r
	assert(absf(hdr_sample.r - hdr_expected) < 0.02, "HDR albedo must remain linear and must not be clipped before exposure")
	material.albedo_texture = null
	material.albedo_color = Color.BLACK
	environment.environment.tonemap_exposure = 1.0
	environment.environment.adjustment_enabled = true
	environment.environment.adjustment_color_correction = preload("res://native_grade.gd").create_texture()
	var lifted := await _sample()
	assert(absf(lifted.r - 0.0702) < 0.015 and absf(lifted.g - 0.0897) < 0.015 and absf(lifted.b - 0.1061) < 0.015, "Native LUT must preserve source teal black lift")
	var grade_samples := [
		[Color(0.18, 0.18, 0.18), Color(0.407752, 0.445717, 0.464804)],
		[Color(0.17, 0.42, 0.83), Color(0.431306, 0.677013, 0.911109)],
		[Color(1, 0, 0), Color(0.949855, 0.089714, 0.106126)],
		[Color(0, 1, 0), Color(0.070165, 0.998460, 0.106126)],
		[Color(0, 0, 1), Color(0.070165, 0.089714, 1.0)]]
	var grade_max_error := 0.0
	for sample in grade_samples:
		material.albedo_color = sample[0].linear_to_srgb()
		var measured := await _sample()
		var target: Color = sample[1]
		grade_max_error = maxf(grade_max_error, maxf(absf(measured.r - target.r), maxf(absf(measured.g - target.g), absf(measured.b - target.b))))
	assert(grade_max_error < 0.025, "Native LUT must preserve color channels and display-space grading")
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment.tonemap_white = 14.26024
	environment.environment.tonemap_exposure = 1.3 / 1.8
	environment.environment.adjustment_color_correction = preload("res://native_grade.gd").create_texture(2)
	var agx_samples := [
		[Color(0.18, 0.18, 0.18), Color(0.373236, 0.412245, 0.432764)],
		[Color(0.17, 0.42, 0.83), Color(0.443453, 0.651305, 0.799329)],
		[Color(1, 0, 0), Color(0.860257, 0.130446, 0.138827)],
		[Color(1, 1, 1), Color(0.863652, 0.838669, 0.799732)]]
	var agx_max_error := 0.0
	for sample in agx_samples:
		material.albedo_color = sample[0].linear_to_srgb()
		var measured := await _sample()
		var target: Color = sample[1]
		agx_max_error = maxf(agx_max_error, maxf(absf(measured.r - target.r), maxf(absf(measured.g - target.g), absf(measured.b - target.b))))
	assert(agx_max_error < 0.025, "Native LUT must approximate the source ACES/AgX blend for uncropped colors")
	print("COLOR_PROBE ", JSON.stringify({"gray": gray.r, "gray_expected": gray_expected,
		"hdr": hdr_sample.r, "hdr_expected": hdr_expected, "grade_black": [lifted.r, lifted.g, lifted.b], "grade_max_error": grade_max_error, "agx_max_error": agx_max_error}))
	quit()

func _sample() -> Color:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	return image.get_pixel(image.get_width() / 2, image.get_height() / 2)
