extends SceneTree
func _initialize()->void:call_deferred("run")
func matrix(a:Array)->Projection:return Projection(Vector4(a[0],a[1],a[2],a[3]),Vector4(a[4],a[5],a[6],a[7]),Vector4(a[8],a[9],a[10],a[11]),Vector4(a[12],a[13],a[14],a[15]))
func texture(values:Array,size:Vector2i)->Texture2D:
 var image=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBAF,PackedFloat32Array(values).to_byte_array());image.flip_y();return ImageTexture.create_from_image(image)
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/motion-gpu-reference.json"))
 if reference==null:quit(2);return
 var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var size=Vector2i(reference.width,reference.height)
 var first=pipeline._filter(size,"res://shaders/source_motion.gdshader",{"tColor":texture(reference.colour,size),"tDepth":texture(reference.depth,size),"uRes":Vector2(size)},true)
 var camera_port=SubViewport.new();camera_port.size=size;owner.add_child(camera_port);var camera=Camera3D.new();camera.fov=74;camera.near=.08;camera.far=900;camera_port.add_child(camera);pipeline.world_camera=camera
 var failures=[];var reports=[];var total=0
 for sample in reference.cases:
  var world=matrix(sample.cameraWorld);camera.global_transform=Transform3D(Basis(Vector3(world.x.x,world.x.y,world.x.z),Vector3(world.y.x,world.y.y,world.y.z),Vector3(world.z.x,world.z.y,world.z.z)),Vector3(world.w.x,world.w.y,world.w.z))
  var actual_matrix=pipeline._source_view_projection();var expected_matrix=matrix(sample.viewProj);var matrix_error=0.0
  for col in 4:
   for row in 4:matrix_error=maxf(matrix_error,absf(actual_matrix[col][row]-expected_matrix[col][row]))
  if matrix_error>.0001:failures.append({"case":sample.name,"matrix_error":matrix_error})
  first.material.set_shader_parameter("uInvViewProj",matrix(sample.invViewProj));first.material.set_shader_parameter("uPrevViewProj",matrix(sample.prevViewProj));first.material.set_shader_parameter("uShutter",sample.shutter)
  await RenderingServer.frame_post_draw
  var image=first.viewport.get_texture().get_image();var maximum=0.0;var sum=0.0;var bad=0
  for y in size.y:
   for x in size.x:
    var actual=image.get_pixel(x,size.y-1-y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*size.x+x)*4+channel]);var error=absf(actual[channel]-expected);maximum=maxf(maximum,error);sum+=error
     if error>maxf(.004,absf(expected)*.003):
      bad+=1
      if failures.size()<20:failures.append({"case":sample.name,"x":x,"y":y,"channel":channel,"expected":expected,"actual":actual[channel],"error":error})
  reports.append({"name":sample.name,"maximum_error":maximum,"mean_error":sum/(size.x*size.y*4),"failing_channels":bad,"camera_matrix_error":matrix_error})
 var report={"cases":reports,"channels":total,"failures":failures,"scope":"Actual original Three Z9 HalfFloat output vs native motion shader, same original matrices/depth/colour. Six stationary/threshold/rotation/translation/fast/combined cases. Tolerance max(.004,.3percent). Native camera matrix generation tested separately."}
 var file=FileAccess.open("res://evidence/motion-reference-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
