extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var demo = load("res://main.tscn").instantiate()
	root.add_child(demo)
	for i in 120:
		await process_frame
	demo.set_process(false)
	var targets: Array[Node3D] = []
	if demo.scene_name == "fx":
		targets.assign(demo.smoke_cards)
	elif demo.scene_name == "ground":
		for child in demo.get_children():
			if child is GPUParticles3D:
				targets.append(child)
	else:
		assert(false, "Use --scene=fx or --scene=ground")
	assert(not targets.is_empty(), "Missing transparent objects")
	for child in demo.get_children():
		if child is GPUParticles3D:
			child.speed_scale = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var visible := root.get_texture().get_image()
	for target in targets:
		target.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	assert(visible.get_size() == hidden.get_size() and visible.get_width() == 1280 and visible.get_height() == 720)
	var changed := 0
	for y in range(100, 350, 2):
		for x in range(0, 1280, 2):
			var a := visible.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 3.0 / 255.0:
				changed += 1
	assert(changed > 100, "Transparent effect disappeared behind the sky")
	print("Transparent ", demo.scene_name, " pixels visible: ", changed)
	demo.queue_free()
	await process_frame
	quit()
