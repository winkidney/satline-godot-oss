extends SceneTree
## Paired UVs isolate texture-unit filtering; no production sampler edits.
func _initialize() -> void:
	call_deferred("run")

func expected(uv: Array, clamp_wrap: bool) -> Color:
	var px := float(uv[0])*2.0-.5
	var py := float(uv[1])*2.0-.5
	var ix := floori(px)
	var iy := floori(py)
	var f := Vector2(px-ix,py-iy)
	var colors := [Color(1,0,0),Color(0,1,0),Color(0,0,1),Color(1,1,1)]
	var corners := []
	for y in 2:
		for x in 2:
			var sx := clampi(ix+x,0,1) if clamp_wrap else posmod(ix+x,2)
			var sy := clampi(iy+y,0,1) if clamp_wrap else posmod(iy+y,2)
			corners.append(colors[sy*2+sx])
	return corners[0].lerp(corners[1],f.x).lerp(corners[2].lerp(corners[3],f.x),f.y)

func run() -> void:
	var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/material-sampler-reference.json"))
	var original_count: int=reference.cases.size()
	for uv in [[.37,.43],[.63,.57],[.4,.35],[.6,.65],[.50001,.4],[-.00001,.4],[.5,.5],[.25,.25]]:
		reference.cases.append({"uv":uv})
	var positions := PackedFloat32Array()
	for sample in reference.cases:
		positions.append_array(PackedFloat32Array([sample.uv[0],sample.uv[1],0,0]))
	var count: int=reference.cases.size()
	var coords := ImageTexture.create_from_image(Image.create_from_data(count,1,false,Image.FORMAT_RGBAF,positions.to_byte_array()))
	var owner := Node3D.new()
	root.add_child(owner)
	var pipeline := SaltlinePostPipeline.new()
	pipeline.owner=owner
	var reports := []
	for floating in [false,true]:
		for srgb in [false,true]:
			for flip_y in [false,true]:
				var bytes := PackedByteArray([255,0,0,255,0,255,0,255,0,0,255,255,255,255,255,255])
				var source := Image.create_from_data(2,2,false,Image.FORMAT_RGBA8,bytes)
				if flip_y:source.flip_y()
				if floating:source.convert(Image.FORMAT_RGBAF)
				var texture := ImageTexture.create_from_image(source)
				for clamp_wrap in [false,true]:
					for manual in [false,true]:
						var target=pipeline._filter(Vector2i(count,1),"res://shaders/source_wet_plain_probe.gdshader",{},true)
						target.viewport.transparent_bg=true
						var shader := Shader.new()
						shader.code="""shader_type canvas_item;
render_mode unshaded,blend_disabled;
uniform sampler2D source_tex:%sfilter_linear,%s;
uniform sampler2D coordinates:filter_nearest,repeat_disable;
ivec2 address(ivec2 p){return %s;}
vec4 fetch_source(ivec2 p){return texelFetch(source_tex,address(%s),0);}
vec4 sample_manual(vec2 uv){vec2 p=uv*2.-.5;ivec2 i=ivec2(floor(p));vec2 f=fract(p);return mix(mix(fetch_source(i),fetch_source(i+ivec2(1,0)),f.x),mix(fetch_source(i+ivec2(0,1)),fetch_source(i+ivec2(1)),f.x),f.y);}
void fragment(){vec2 uv=texelFetch(coordinates,ivec2(int(FRAGCOORD.x),0),0).xy;COLOR=%s;}
""" % ["source_color," if srgb else "","repeat_disable" if clamp_wrap else "repeat_enable","clamp(p,ivec2(0),ivec2(1))" if clamp_wrap else "((p%2)+2)%2","ivec2(p.x,1-p.y)" if flip_y else "p","sample_manual(uv)" if manual else ("textureLod(source_tex,vec2(uv.x,1.-uv.y),0.)" if flip_y else "textureLod(source_tex,uv,0.)")]
						target.material.shader=shader
						target.material.set_shader_parameter("source_tex",texture)
						target.material.set_shader_parameter("coordinates",coords)
						await RenderingServer.frame_post_draw
						await RenderingServer.frame_post_draw
						var output: Image=target.viewport.get_texture().get_image()
						var cases := []
						var maximum := 0.0
						var matched_reference_max := 0.0
						var failures := 0
						for i in count:
							var actual := output.get_pixel(i,0)
							var ideal := expected(reference.cases[i].uv,clamp_wrap)
							var error := 0.0
							for channel in 3:
								error=maxf(error,absf(actual[channel]-ideal[channel]))
								if i<original_count and clamp_wrap==bool(reference.cases[i].clamp):matched_reference_max=maxf(matched_reference_max,absf(actual[channel]-reference.cases[i].pixels[channel]))
							maximum=maxf(maximum,error)
							if error>.002:failures+=1
							cases.append({"case":i,"uv":reference.cases[i].uv,"actual":[actual.r,actual.g,actual.b],"ideal":[ideal.r,ideal.g,ideal.b],"maximum_error":error})
						var report := {"format":"RGBA32F" if floating else "RGBA8","srgb_hint":srgb,"flip_y":flip_y,"clamp":clamp_wrap,"manual":manual,"max_vs_ideal":maximum,"max_vs_matching_original_cases":matched_reference_max,"failures_above_002":failures,"cases":cases}
						reports.append(report)
						print(JSON.stringify({"format":report.format,"srgb":srgb,"flip":flip_y,"clamp":clamp_wrap,"manual":manual,"max":maximum,"source_max":matched_reference_max,"failed":failures,"case1":cases[1].actual}))
						target.viewport.queue_free()
						await process_frame
	FileAccess.open("res://evidence/sampler-filter-precision-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Paired 48 original UVs plus 8 interior/boundary UVs for clamp/repeat, RGBA8/RGBAF, source_color/plain, original/flipped upload, hardware explicit LOD0/manual four-fetch filtering; ideal math is diagnostic and original reference retained","reports":reports},"  "))
	owner.queue_free()
	await process_frame
	quit()
