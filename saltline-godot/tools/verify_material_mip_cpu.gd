extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/material-mip-reference.json"));var bytes=PackedByteArray()
 for y in 4:
  for x in 4:
   var value=255 if (x+y)%2 else 0;bytes.append_array(PackedByteArray([value,value,value,255]))
 var image=Image.create_from_data(4,4,false,Image.FORMAT_RGBA8,bytes);image.generate_mipmaps();var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_material_mip_probe.gdshader",{"source_tex":ImageTexture.create_from_image(image)},true);var reports=[];var failures=[]
 for sample in reference.cases:
  target.material.set_shader_parameter("lod",sample.lod);await RenderingServer.frame_post_draw;var actual=target.viewport.get_texture().get_image().get_pixel(0,0);var error=absf(actual.r-sample.pixels[0]);reports.append({"lod":sample.lod,"actual":actual.r,"expected":sample.pixels[0],"error":error})
  if error>.002:failures.append(sample.lod)
 var report={"cases":reports,"failures":failures,"scope":"Original Three SRGB RGBA8 glGenerateMipmap checker vs current Image.generate_mipmaps native encodedRGBA8 path;explicit textureLod. Diagnostic,not full assets."};FileAccess.open("res://evidence/material-mip-cpu-failure.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
