extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var spec=JSON.parse_string(FileAccess.get_file_as_string("res://tools/weapon_hash_diagnostic.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,1),"res://shaders/source_sun_brdf_probe.gdshader",{},true);target.viewport.transparent_bg=true
 var cases=[]
 for mode in spec.modes:
  var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;\n"+spec.common+"\nvoid fragment(){float value="+mode.expression+";uint bits=floatBitsToUint(value);COLOR=FRAGCOORD.x<1.0?vec4(float(bits&255u),float((bits>>8u)&255u),float((bits>>16u)&255u),1):vec4(float((bits>>24u)&255u),0,0,1);}";target.material.shader=shader;target.material.set_shader_parameter("uGuard",0)
  for sample in spec.cases:
   target.material.set_shader_parameter("uP",Vector3(sample.point[0],sample.point[1],sample.point[2]));target.material.set_shader_parameter("uAngle",sample.angle)
   await process_frame;RenderingServer.force_draw(false);var image=target.viewport.get_texture().get_image();var first=image.get_pixel(0,0);var last=image.get_pixel(1,0);var bytes=PackedByteArray([roundi(first.r),roundi(first.g),roundi(first.b),roundi(last.r)])
   cases.append({"case":sample.name,"mode":mode.name,"bytes":Array(bytes),"bits":bytes.decode_u32(0),"value":bytes.decode_float(0)})
 var report={"schema":1,"cases":cases,"backend":RenderingServer.get_video_adapter_name(),"scope":"Independent diagnostic dot/sin/multiply/fract and runtime-zero-guard variants; exact float32 bytes in two RGBA16F pixels. No production edits."};FileAccess.open("res://evidence/weapon-hash-native-diagnostic.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":cases.size(),"backend":report.backend}));owner.queue_free();await process_frame;quit()
