extends SceneTree
var failures=[]
var samples=[]
func image_stats(image:Image)->Dictionary:
 var lo=INF;var hi=-INF;var invalid=0;var count=0;var lit=0
 for y in range(0,image.get_height(),8):
  for x in range(0,image.get_width(),8):
   var pixel=image.get_pixel(x,y)
   var value=(pixel.r+pixel.g+pixel.b)/3.0
   count+=1
   if not is_finite(value):invalid+=1;continue
   lo=minf(lo,value);hi=maxf(hi,value)
   if value>.001:lit+=1
 return {"minimum":lo,"maximum":hi,"nonfinite":invalid,"sample_count":count,"lit_samples":lit}
func _initialize()->void:call_deferred("run")
func run()->void:
 var args=OS.get_cmdline_user_args()
 var quality=args[-1]
 if quality not in ["low","medium","high","ultra"] or not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/saltline-quality-cold-"):
  push_error("Requires a quality argument and isolated /tmp/saltline-quality-cold-* XDG_DATA_HOME");quit(1);return
 var file=FileAccess.open("user://saltline-settings.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"quality":quality}));file.close()
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 var preset=game.render_quality.PRESETS[quality]
 if game.game_ui.settings.quality!=quality or game.render_quality.current!=quality:failures.append("saved preset not applied during boot")
 for frame in 8:
  game._process(1.0/60)
  await process_frame
  RenderingServer.force_draw(false)
  var pipeline=game.post_pipeline
  var row={"frame":frame,"depth":pipeline.combined_depth.is_ready(),"half_depth":pipeline.half_depth.is_ready(),"sun":game.sun_shadow_pass.depth.is_ready_for(game.sun_shadow_pass.viewport.size),"reflection":game.planar_reflection.capture.is_ready() if preset.planar>0 else false,"size":[pipeline.world_port.size.x,pipeline.world_port.size.y]}
  var world=pipeline.world_port.get_texture().get_image()
  row.world_pixels=image_stats(world)
  if row.world_pixels.nonfinite>0 or row.world_pixels.maximum-row.world_pixels.minimum<.01 or row.world_pixels.lit_samples<10:failures.append("invalid or blank UI-free world frame %d"%frame)
  if frame in [0,7]:
   world.convert(Image.FORMAT_RGB8)
   world.save_png("res://evidence/quality-cold-%s-world-%d.png"%[quality,frame])
  samples.append(row)
  var expected=game.render_quality.resolution(root.size,preset)
  if pipeline.world_port.size!=expected or pipeline.weapon_port.size!=expected:failures.append("wrong render size frame %d"%frame)
  if pipeline.ao_enabled!=preset.ao or pipeline.motion_enabled!=preset.motionBlur:failures.append("post gates frame %d"%frame)
  if game.sun_shadow_pass.viewport.size.x!=preset.shadow:failures.append("shadow size frame %d"%frame)
  if frame>=2 and (not row.depth or not row.half_depth or not row.sun):failures.append("depth not ready frame %d"%frame)
  if frame>=2 and preset.planar>0 and not row.reflection:failures.append("reflection not ready frame %d"%frame)
  if preset.planar==0 and game.planar_reflection.report.get("active",false):failures.append("low reflection active")
 var image=root.get_texture().get_image()
 image.save_png("res://evidence/quality-cold-"+quality+".png")
 var minimum=1.0;var maximum=0.0
 for y in range(0,image.get_height(),8):
  for x in range(0,image.get_width(),8):
   var pixel=image.get_pixel(x,y);var luma=(pixel.r+pixel.g+pixel.b)/3
   minimum=minf(minimum,luma);maximum=maxf(maximum,luma)
 if maximum-minimum<.05:failures.append("flat or blank final output")
 var report={"quality":quality,"failures":failures,"samples":samples,"luma_range":[minimum,maximum],"scope":"Separate-process saved-quality cold boot, real GPU draws, render/depth/shadow/planar readiness by frame 2, UI-free HDR world pixel finite/range/nonblank checks at all eight observations and post gates. Not original pixel parity, first-draw visual continuity, performance, or device auto selection. World PNGs clamp HDR to RGB8 for inspection; statistics use original HDR pixels."}
 FileAccess.open("res://evidence/quality-cold-"+quality+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
