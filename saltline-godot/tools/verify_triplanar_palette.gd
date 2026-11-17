extends SceneTree
func _initialize()->void:call_deferred("run")
func matrix_error(image:Image,row:int,expected:Projection)->float:
 var maximum=0.0
 for col in 4:
  var pixel=image.get_pixel(col,row)
  for channel in 4:maximum=maxf(maximum,absf(pixel[channel]-expected[col][channel]))
 return maximum
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/triplanar-palette-reference.json"));var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();await RenderingServer.frame_post_draw;var palette=scene.tri_palette;var image=palette.texture.get_image();var bindings={}
 for binding in palette.bindings:bindings[str(binding.node.get_meta("source_id"))]=binding
 var failures=[];var maximum=0.0;var matrices=0
 for sample in reference.cases:
  var binding=bindings[sample.mesh]
  for slot in sample.matrices.size():
   var expected=preload("res://scripts/planar_camera.gd").matrix(sample.matrices[slot]);var error=matrix_error(image,binding.base+slot,expected);maximum=maxf(maximum,error);matrices+=1
   if error>.00005 and failures.size()<20:failures.append({"mesh":sample.mesh,"slot":slot,"error":error})
 var target=palette.bindings[0];var skeleton:Skeleton3D=target.skeleton;var original=skeleton.get_bone_pose(0);skeleton.set_bone_pose(0,original*Transform3D(Basis(Vector3.UP,.37),Vector3(.1,.2,.05)));skeleton.force_update_all_bone_transforms();await RenderingServer.frame_post_draw;var changed=palette.texture.get_image();var updated_max=0.0;var changed_values=0;var unrelated=0
 for binding in palette.bindings:
  var to_mesh=binding.node.global_transform.affine_inverse()*binding.skeleton.global_transform
  for slot in binding.skin.get_bind_count():
   var bone=binding.skin.get_bind_bone(slot);var expected=Projection(to_mesh*binding.skeleton.get_bone_global_pose(bone)*binding.skin.get_bind_pose(slot));var error=matrix_error(changed,binding.base+slot,expected);updated_max=maxf(updated_max,error)
   if error>.00005 and failures.size()<20:failures.append({"runtime_slot":binding.base+slot,"error":error})
   for col in 4:
    if image.get_pixel(col,binding.base+slot)!=changed.get_pixel(col,binding.base+slot):
     if binding.skeleton==skeleton:changed_values+=1
     else:unrelated+=1
 if changed_values<1:failures.append("skeleton_updated did not update GPU palette")
 if unrelated>0:failures.append("shared material palette overwrote other actors")
 var report={"source_meshes":reference.cases.size(),"source_matrices":matrices,"initial_maximum_error":maximum,"runtime_maximum_error":updated_max,"changed_target_texels":changed_values,"changed_unrelated_texels":unrelated,"atlas_size":[image.get_width(),image.get_height()],"failures":failures,"scope":"GPU-read RGBA32F palette initial18actor/290slots against original exported Three attached skin matrices; one skeleton root mutation first-renderframe update vs native currentposes, unrelated actor slots unchanged. Diagnostic readback only; not full finalnormal image or all animation parity."};var file=FileAccess.open("res://evidence/triplanar-palette-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
