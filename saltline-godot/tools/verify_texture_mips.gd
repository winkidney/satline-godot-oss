extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();await RenderingServer.frame_post_draw;var failures=[];var reports=[];var total=0;var raw_sky={}
 for material in scene.source.materials:
  if material.name=="saltline-sky":raw_sky[material.uniforms.tNoise.value["$texture"]]=true
 var entries=[]
 for id in scene.textures:entries.append({"id":id,"texture":scene.textures[id],"original_rows":false})
 for id in scene.source_row_textures:entries.append({"id":id,"texture":scene.source_row_textures[id],"original_rows":true})
 for entry in entries:
  var id=entry.id;var record=scene.texture_records[id];var image=entry.texture.get_image();var data=image.get_data();var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(data);var digest=context.finish().hex_encode();var expected=str(record.get("godot_source_mip_sha256" if entry.original_rows else "godot_mip_sha256",""));total+=data.size()
  var orientation="original-bottom-to-top generic" if entry.original_rows else "prepared-top-to-bottom"
  if raw_sky.has(id):
   var raw_context=HashingContext.new();raw_context.start(HashingContext.HASH_SHA256);raw_context.update(FileAccess.get_file_as_bytes("res://assets/export/"+record.file));expected=raw_context.finish().hex_encode();orientation="original-bottom-to-top sky shader contract"
  var valid=digest==expected and image.has_mipmaps()==record.godot_has_mipmaps
  if not valid:failures.append({"texture":id,"digest":digest,"expected":expected})
  reports.append({"texture":id,"width":image.get_width(),"height":image.get_height(),"mip_count":image.get_mipmap_count(),"bytes":data.size(),"match":valid,"orientation":orientation})
 var report={"textures":reports,"bytes":total,"failures":failures,"scope":"Actual runtime texture factory GPU readback All runtime original-row generic and prepared-row dedicated RGBA8 mip variants plus sky original raw orientation SHA256 vs original Three glGenerateMipmap exports; verifies uploaded texel data and presence,not hardware bilinear/trilinear/aniso sampling."};FileAccess.open("res://evidence/texture-mips-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"textures":reports.size(),"bytes":total,"failures":failures}));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
