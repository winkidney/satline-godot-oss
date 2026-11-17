extends SceneTree
func _initialize()->void:call_deferred("run")
func memory()->int:return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
func run()->void:
 var owner=Node3D.new();root.add_child(owner);root.disable_3d=true;var source=SaltlineSourceScene.new();owner.add_child(source);source.load_source()
 for frame in 3:await process_frame
 await RenderingServer.frame_post_draw
 var before=memory();var snapshots=[];var failures=[]
 for cycle in 2:
  var start=Time.get_ticks_usec();var shadow=SaltlineSunShadowPass.new();shadow.setup(owner,source,4096)
  for frame in 3:shadow.update();await RenderingServer.frame_post_draw
  var active=memory();var draw_calls=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME);var primitives=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
  var image=shadow.depth.output.get_image();var minimum=1.0;var maximum=0.0;var covered=0;var sampled=0
  for y in range(0,4096,8):
   for x in range(0,4096,8):
    var value=image.get_pixel(x,y).r;minimum=minf(minimum,value);maximum=maxf(maximum,value);sampled+=1
    if value<.99999:covered+=1
  if image.get_size()!=Vector2i(4096,4096) or image.get_format()!=Image.FORMAT_RF or not shadow.depth.is_ready() or covered<100 or shadow.report.eligible!=148 or shadow.report.skin!=18 or shadow.report.multimesh!=6 or not shadow.report.unsupported.is_empty():failures.append({"cycle":cycle,"size":str(image.get_size()),"format":image.get_format(),"casters":shadow.report,"covered":covered})
  if cycle==0:
   var visual=image.duplicate();visual.convert(Image.FORMAT_RGB8);visual.save_png("res://evidence/sun-shadow-source-4096.png")
  var caster_report=shadow.report.duplicate(true);var elapsed=(Time.get_ticks_usec()-start)/1000.0
  shadow.dispose();shadow=null;image=null
  for frame in 5:await process_frame
  await RenderingServer.frame_post_draw
  var after=memory()
  snapshots.append({"cycle":cycle,"casters":caster_report,"minimum_depth":minimum,"maximum_depth":maximum,"sampled":sampled,"covered_samples":covered,"active_video_memory_bytes":active,"added_video_memory_bytes":active-before,"after_cleanup_video_memory_bytes":after,"draw_calls_last_update_frame":draw_calls,"primitives_last_update_frame":primitives,"wall_time_ms_including_setup_shader_compile_readback":elapsed})
 if snapshots[1].after_cleanup_video_memory_bytes>snapshots[0].after_cleanup_video_memory_bytes+8*1024*1024:failures.append("Second cleanup retained >8MiB extra GPU memory")
 var report={"resolution":4096,"format":"R32F","failures":failures,"baseline_video_memory_bytes":before,"snapshots":snapshots,"scope":"Actual originalprepared scene148casters including6MultiMesh and18skinned proxies, independent4096square sourcefrustum shadow pass, two create/render/dispose cycles. GPU memory counters include all engineattachments and caches, walltime includes readback/compiler, not steadyGPU timing. Nonemptydepth and eligibility tested, not entire original4096map pixelparity or highframe performance acceptance."};var file=FileAccess.open("res://evidence/sun-shadow-scene-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
