extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var palette=game.source_scene.tri_palette;var previous:Image;var changed_frames=0;var maximum=0.0;var failures=[];var samples=0
 for frame in 150:
  await RenderingServer.frame_post_draw
  if frame%10!=0:continue
  var image=palette.texture.get_image();var changed=false
  for binding in palette.bindings:
   var to_mesh=binding.node.global_transform.affine_inverse()*binding.skeleton.global_transform
   for slot in binding.skin.get_bind_count():
    var name=binding.skin.get_bind_name(slot);var bone=binding.skeleton.find_bone(name) if not str(name).is_empty() else binding.skin.get_bind_bone(slot)
    var expected=Projection(to_mesh*binding.skeleton.get_bone_global_pose(bone)*binding.skin.get_bind_pose(slot))
    for col in 4:
     var pixel=image.get_pixel(col,binding.base+slot)
     for channel in 4:maximum=maxf(maximum,absf(pixel[channel]-expected[col][channel]))
     if previous!=null and pixel!=previous.get_pixel(col,binding.base+slot):changed=true
  if changed:changed_frames+=1
  previous=image;samples+=1
 if maximum>.00005:failures.append("GPU palette differs from current animated poses")
 if changed_frames<10:failures.append("insufficient continuous animation changes")
 var report={"samples":samples,"changed_samples":changed_frames,"maximum_error":maximum,"failures":failures,"arguments":OS.get_cmdline_user_args(),"scope":"150 actual actor-preview frames; GPU palette read every10 frames vs current Skeleton poses across18 meshes. Does not establish full final-image normal parity."}
 var file=FileAccess.open("res://evidence/triplanar-animation-"+("gull" if game.gull_preview else "hound")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
