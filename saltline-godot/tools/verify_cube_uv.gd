extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/cube-uv-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_cube_uv_probe.gdshader",{},true);var envs=preload("res://scripts/pmrem_textures.gd").new();envs.load_source();var failures=[];var reports=[];var channels=0;var uploads=[]
 await RenderingServer.frame_post_draw
 for id in envs.textures:
  var image=envs.textures[id].get_image();image.convert(Image.FORMAT_RGBAF);var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(image.get_data());var matches=context.finish().hex_encode()==envs.records[id].sha256;uploads.append({"texture":id,"rgba32f_roundtrip_matches":matches})
  if not matches:failures.append({"texture":id,"error":"HDR GPU upload readback differs from original"})
 for i in reference.cases.size():
  var sample=reference.cases[i];var record=envs.records[sample.texture];target.material.set_shader_parameter("uEnv",envs.textures[sample.texture]);target.material.set_shader_parameter("source_env_texel",Vector2(1.0/record.width,1.0/record.height));target.material.set_shader_parameter("source_env_max_mip",log(float(record.height))/log(2.0)-2.0);target.material.set_shader_parameter("uDirection",Vector3(sample.direction[0],sample.direction[1],sample.direction[2]));target.material.set_shader_parameter("uRoughness",sample.roughness);await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);var limit=maxf(.001,absf(expected)*.0015);maximum=maxf(maximum,error);channels+=1
     if error>limit and failures.size()<30:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error,"limit":limit})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"hdr_uploads":uploads,"channels":channels,"failures":failures,"scope":"Original literal CubeUV vs production helper and HDR loader,canonical NVIDIA original-rowRGBA16F PMREM,224 direction/roughness/texture cases. Preset absolute.001 or relative.0015,whichever greater. Not full indirectBRDF/material integration."};FileAccess.open("res://evidence/cube-uv-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":reports.size(),"hdr_uploads":uploads,"channels":channels,"failures":failures}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
