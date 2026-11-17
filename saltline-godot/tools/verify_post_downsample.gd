extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/post-gpu-reference.json"))
 if not data.has("down_reference"):printerr("Regenerate original GPU fixture with down_reference first");quit(2);return
 var reference=data.down_reference
 var image=Image.create_from_data(reference.width,reference.height,false,Image.FORMAT_RGBAF,PackedFloat32Array(reference.input).to_byte_array());image.flip_y()
 var previous:Texture2D=ImageTexture.create_from_image(image);var width=int(reference.width);var height=int(reference.height);var ports=[]
 for index in 2:
  var viewport=SubViewport.new();viewport.size=Vector2i(width/2,height/2);viewport.use_hdr_2d=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);ports.append(viewport)
  var material=ShaderMaterial.new();material.shader=load("res://shaders/source_downsample.gdshader");material.set_shader_parameter("tSrc",previous);material.set_shader_parameter("uTexel",Vector2(1.0/width,1.0/height));material.set_shader_parameter("uFirst",1.0 if index==0 else 0.0)
  var rect=ColorRect.new();rect.size=viewport.size;rect.material=material;viewport.add_child(rect);previous=viewport.get_texture();width/=2;height/=2
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var failures=[];var maximum=0.0;var comparisons=0
 for index in 2:
  var expected=reference.levels[index];var output=ports[index].get_texture().get_image()
  for y in expected.height:
   for x in expected.width:
    var actual=output.get_pixel(x,int(expected.height)-1-y)
    for channel in 3:
     var target=float(expected.color[(y*int(expected.width)+x)*4+channel]);var error=absf(actual[channel]-target);maximum=maxf(maximum,error);comparisons+=1
     if error>maxf(.003,absf(target)*.003):failures.append("%d %d,%d %d"%[index,x,y,channel])
 var report={"levels":2,"pixels":160,"channels":comparisons,"failures":failures,"maximum_error":maximum,"scope":"Actual original j9 Three Float32 GPU reference vs native HDR RGBA16F two-level GPU output; nonuniform HDR gradient and 300-radiance point, first partial-Karis then ordinary13-tap. Original sampling/weights retained, tolerance max(.003,.3percent radiance)."}
 var file=FileAccess.open("res://evidence/post-downsample-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report))
 for viewport in ports:viewport.queue_free()
 await process_frame;quit(0 if failures.is_empty() else 1)
