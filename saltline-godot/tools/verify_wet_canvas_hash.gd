extends SceneTree
## Encodes FP32 hash bits as four byte values in HDR canvas pixels.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/wet-hash-diagnostic-input.json"))
	var test_noise := "--noise" in OS.get_cmdline_user_args()
	var dataset: Array=reference.noise_points if test_noise else reference.cases
	var points := PackedFloat32Array()
	for item in dataset:
		var point: Array=item.point if test_noise else item.cell
		points.append_array(PackedFloat32Array([point[0],point[1],point[2],0]))
	var count: int=dataset.size()
	var texture := ImageTexture.create_from_image(Image.create_from_data(count,1,false,Image.FORMAT_RGBAF,points.to_byte_array()))
	var modes := {
		"plain":"float slH(vec3 p){p=fract(p*.3183099+vec3(.71,.113,.419));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}",
		"full_guard":"float slH(vec3 p){vec3 q=R3(R3(p*.3183099)+vec3(.71,.113,.419));q=R3(fract(q));q=R3(q*17.);float xy=R(q.x*q.y);float xyz=R(xy*q.z);float sx=R(q.x+q.y);float s=R(sx+q.z);return fract(R(xyz*s));}"
	}
	modes["full_guard_input"]=modes.full_guard.replace("vec3 q=","p=R3(p);vec3 q=")
	var noise_code := FileAccess.get_file_as_string("res://assets/export/fixtures/source-wet-noise-original.glsl")
	noise_code=noise_code.substr(noise_code.find("float slN3(")) if test_noise else ""
	var owner := Node3D.new()
	root.add_child(owner)
	var pipeline := SaltlinePostPipeline.new()
	pipeline.owner=owner
	var reports := []
	for mode in modes:
		var target=pipeline._filter(Vector2i(count,1),"res://shaders/source_wet_probe.gdshader",{},true)
		target.viewport.transparent_bg=true
		var shader := Shader.new()
		shader.code="""shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D diagnostic_points:filter_nearest,repeat_disable;
uniform uint diagnostic_guard=0u;
float R(float x){return uintBitsToFloat(floatBitsToUint(x)+diagnostic_guard);}
vec3 R3(vec3 x){return uintBitsToFloat(floatBitsToUint(x)+uvec3(diagnostic_guard));}
%s
%s
void fragment(){vec3 p=texelFetch(diagnostic_points,ivec2(int(FRAGCOORD.x),0),0).xyz;uint b=floatBitsToUint(%s(p));COLOR=vec4(float(b&255u),float((b>>8u)&255u),float((b>>16u)&255u),float((b>>24u)&255u))/255.;}
""" % [modes[mode],noise_code,"slN3" if test_noise else "slH"]
		target.material.shader=shader
		target.material.set_shader_parameter("diagnostic_points",texture)
		target.material.set_shader_parameter("diagnostic_guard",0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image=target.viewport.get_texture().get_image()
		var failures := []
		var bits := []
		var maximum := 0.0
		var conversion := PackedByteArray()
		conversion.resize(8)
		for i in count:
			var c := image.get_pixel(i,0)
			var actual := roundi(c.r*255)|(roundi(c.g*255)<<8)|(roundi(c.b*255)<<16)|(roundi(c.a*255)<<24)
			var expected: int=dataset[i].expected_bits if test_noise else dataset[i].expected_bits[17]
			conversion.encode_u32(0,actual)
			conversion.encode_u32(4,expected)
			maximum=maxf(maximum,absf(conversion.decode_float(0)-conversion.decode_float(4)))
			bits.append(actual)
			if actual!=expected:
				failures.append({"point":dataset[i].point if test_noise else dataset[i].cell,"actual":actual,"expected":expected})
		reports.append({"mode":mode,"mismatches":failures.size(),"maximum_float_error":maximum,"bits":bits,"failures":failures})
		print(JSON.stringify({"mode":mode,"mismatches":failures.size(),"maximum_float_error":maximum,"first_bits":bits[0]}))
		target.viewport.queue_free()
		await process_frame
	var destination := "res://evidence/wet-canvas-noise-verification.json" if test_noise else "res://evidence/wet-canvas-hash-verification.json"
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify({"scope":"Canvas hash/noise uint bits vs separated CPU float32; diagnostic only","reports":reports},"  "))
	owner.queue_free()
	await process_frame
	quit()
