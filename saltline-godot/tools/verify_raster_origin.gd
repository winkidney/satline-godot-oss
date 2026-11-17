extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(RenderingServer.has_method("viewport_set_source_raster_y_up"))
	var failures: Array = []
	var ports: Array = []
	var rows: Array = []
	# Share each material between simultaneous opposite-origin viewports to catch cache contamination.
	for case_index in 6:
		var cull: String = ["back", "front", "disabled"][case_index % 3]
		var alpha_code := "ALPHA=0.55;" if case_index >= 3 else ""
		var shader := Shader.new()
		shader.code = "shader_type spatial;render_mode unshaded,cull_%s;void fragment(){ALBEDO=FRONT_FACING?vec3(0.,1.,0.):vec3(1.,0.,0.);if(SOURCE_RASTER_Y_UP!=(PROJECTION_MATRIX[1][1]>0.0)){ALBEDO=vec3(0.,0.,1.);}%s}" % [cull, alpha_code]
		var material := ShaderMaterial.new()
		material.shader = shader
		for source_origin in [false, true]:
			var port := SubViewport.new()
			port.size = Vector2i(65, 37)
			port.own_world_3d = true
			port.use_hdr_2d = true
			port.msaa_3d = Viewport.MSAA_4X
			port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			RenderingServer.viewport_set_source_raster_y_up(port.get_viewport_rid(), source_origin)
			root.add_child(port)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color.BLACK
			environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			port.add_child(environment)
			var camera := Camera3D.new()
			camera.position.z = 2.0
			port.add_child(camera)
			camera.make_current()
			var node := MeshInstance3D.new()
			node.mesh = QuadMesh.new()
			node.position.y = 0.25
			node.material_override = material
			port.add_child(node)
			ports.append(port)
	for size in [Vector2i(65, 37), Vector2i(67, 39)]:
		for port in ports:
			port.size = size
		for frame in 5:
			await process_frame
			RenderingServer.force_draw(false)
		for pair in 6:
			var normal: Image = ports[pair * 2].get_texture().get_image()
			var flipped: Image = ports[pair * 2 + 1].get_texture().get_image()
			flipped.flip_y()
			var same := normal.get_data() == flipped.get_data()
			var center := normal.get_pixel(size.x / 2, size.y / 2)
			var expected := 0.55 if pair >= 3 else 1.0
			var facing_ok := absf(center.g - expected) < 0.001 if pair % 3 != 1 else center.g < 0.01
			rows.append({"size": [size.x, size.y], "cull": ["back", "front", "disabled"][pair % 3], "normalized_bytes_equal": same, "facing_ok": facing_ok, "center_rgb": [center.r, center.g, center.b], "transparent": pair >= 3})
			if not same or not facing_ok:
				failures.append(rows.back())
	var report := {"rows": rows, "failures": failures, "scope": "Forward+ MSAA4 shared-material opposite-origin viewports, cull/front-facing, per-scene shader flag, opaque/transparent and odd resize. Does not prove game post-processing or original scene parity."}
	FileAccess.open("res://evidence/raster-origin-verification.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	for port in ports:
		port.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
