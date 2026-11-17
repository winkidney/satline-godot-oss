extends SceneTree
## Isolated canvas variants; never modifies production shaders or original fixtures.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/wet-reference.json"))
	var base := FileAccess.get_file_as_string("res://shaders/source_wet_plain_probe.gdshader")
	var start := base.find("float slH(")
	var end := base.find("float slN3(",start)
	var prefix := "uniform uint diagnostic_guard=0u;\nfloat R(float x){return uintBitsToFloat(floatBitsToUint(x)+diagnostic_guard);}\nvec3 R3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(diagnostic_guard));}\n"
	var modes := {
		"plain":"float slH(vec3 p){p=fract(p*.3183099+vec3(.71,.113,.419));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}\n",
		"first_guard":"float slH(vec3 p){p=fract(R3(p*.3183099)+vec3(.71,.113,.419));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}\n",
		"full_guard":"float slH(vec3 p){vec3 q=R3(R3(p*.3183099)+vec3(.71,.113,.419));q=R3(fract(q));q=R3(q*17.);float xy=R(q.x*q.y);float xyz=R(xy*q.z);float sx=R(q.x+q.y);float s=R(sx+q.z);return fract(R(xyz*s));}\n"
	}
	modes["full_guard_input"]=modes.full_guard.replace("vec3 q=","p=R3(p);vec3 q=")
	modes["first_guard_input"]=modes.first_guard.replace("{p=fract", "{p=R3(p);p=fract")
	modes["reduced_guard_input"]="float slH(vec3 p){p=R3(p);p=fract(R3(p*.3183099)+vec3(.71,.113,.419));p=R3(p*17.);float xy=R(p.x*p.y);float xyz=R(xy*p.z);float sum=R(R(p.x+p.y)+p.z);return fract(R(xyz*sum));}\n"
	var owner := Node3D.new()
	root.add_child(owner)
	var pipeline := SaltlinePostPipeline.new()
	pipeline.owner=owner
	var reports := []
	for mode in modes:
		var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_wet_plain_probe.gdshader",{},true)
		target.viewport.transparent_bg=true
		var shader := Shader.new()
		shader.code=base.substr(0,start)+prefix+modes[mode]+base.substr(end)
		target.material.shader=shader
		target.material.set_shader_parameter("diagnostic_guard",0)
		var failures := []
		var cases := []
		var maximum := 0.0
		for i in reference.cases.size():
			var sample=reference.cases[i]
			for key in sample.vectors:
				var v=sample.vectors[key]
				target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
			target.material.set_shader_parameter("uMacro",Vector4(sample.macro[0],sample.macro[1],sample.macro[2],sample.macro[3]))
			target.material.set_shader_parameter("uParams",Vector4(sample.params[0],sample.params[1],sample.params[2],sample.params[3]))
			target.material.set_shader_parameter("uTri",sample.tri)
			target.material.set_shader_parameter("uTint",sample.tint)
			target.material.set_shader_parameter("uRain",sample.rain)
			target.material.set_shader_parameter("uIndoor",sample.indoor)
			await RenderingServer.frame_post_draw
			var image: Image=target.viewport.get_texture().get_image()
			var pixels := []
			var local_max := 0.0
			for y in 2:
				for x in 2:
					var pixel := image.get_pixel(x,y)
					for channel in 4:
						var expected: float=sample.pixels[(y*2+x)*4+channel]
						var error := absf(pixel[channel]-expected)
						pixels.append(pixel[channel])
						maximum=maxf(maximum,error)
						local_max=maxf(local_max,error)
						if error>.001:
							failures.append({"case":i,"pixel":[x,y],"channel":channel,"expected":expected,"actual":pixel[channel],"error":error})
			cases.append({"case":i,"maximum_error":local_max,"pixels":pixels})
		reports.append({"mode":mode,"maximum_error":maximum,"failures":failures,"cases":cases,"shader_code":shader.code})
		print(JSON.stringify({"mode":mode,"maximum_error":maximum,"failed_channels":failures.size()}))
		target.viewport.queue_free()
		await process_frame
	FileAccess.open("res://evidence/wet-guard-variants-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Isolated full wet canvas variants vs unchanged original Three half-float fixture, .001 tolerance","reports":reports},"  "))
	owner.queue_free()
	await process_frame
	quit()
