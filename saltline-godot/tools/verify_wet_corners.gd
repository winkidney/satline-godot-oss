extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/wet-corners-nvidia-gl.json"))
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner
 var shader=Shader.new();shader.code='shader_type canvas_item;render_mode unshaded,blend_disabled;uniform vec3 point;\n#include "res://shaders/source_material_noise.gdshaderinc"\nvoid fragment(){COLOR=vec4(slH(point),0.,0.,1.);}'
 var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_wet_nvidia_probe.gdshader",{},true);target.material.shader=shader;target.viewport.transparent_bg=true
 var results=[]
 for sample in reference.cases:
  var p=sample.vectors.uPos;target.material.set_shader_parameter("point",Vector3(p[0],p[1],p[2]))
  await process_frame;RenderingServer.force_draw(false)
  var actual=target.viewport.get_texture().get_image().get_pixel(0,0).r
  results.append({"point":p,"reference":sample.pixels[0],"native":actual,"error":absf(actual-sample.pixels[0])})
 var report={"corners":results,"scope":"Independent original NVIDIA GL vs production hash at exact integer first-layer corners. Compiler-context diagnostic, not full inline-noise acceptance."}
 FileAccess.open("res://evidence/wet-corners-nvidia-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 owner.queue_free();await process_frame;quit()
