extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 var reports=[];var failures=[]
 for profile in [{"name":"apron_wet","position":Vector3(-24,1.4,6),"look":Vector3(-10,-.1,1)},{"name":"sea","position":Vector3(34,2,6),"look":Vector3(30,-1.6,3)},{"name":"saltline_arm","position":Vector3(-25,1.68,6),"look":Vector3(0,1.6,-8)}]:
  var material:ShaderMaterial
  for record in game.source_scene.source.materials:
   if record.name==profile.name:material=game.source_scene.materials[record.id]
  if material==null:failures.append("missing material "+profile.name);continue
  game.camera.global_position=profile.position;game.camera.look_at(profile.look,Vector3.UP);var images=[]
  for enabled in [false,true]:
   for warm in 12:
    game._process(0.0);material.set_shader_parameter("source_ibl_radiance_enabled",enabled);await RenderingServer.frame_post_draw
   images.append(game.post_pipeline.scene_port.get_texture().get_image());root.get_texture().get_image().save_png("res://evidence/special-ibl-"+profile.name+("-on.png" if enabled else "-off.png"))
  var changed=0;var maximum=0.0;var sum=0.0
  for y in range(0,images[0].get_height(),4):
   for x in range(0,images[0].get_width(),4):
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);sum+=delta;maximum=maxf(maximum,delta)
    if delta>.003:changed+=1
  reports.append({"material":profile.name,"ready":material.get_shader_parameter("source_ibl_ready"),"changed_hdr_samples":changed,"maximum_rgb_difference":maximum,"sum_rgb_difference":sum})
  if changed<3:failures.append("missing special IBL contribution "+profile.name)
 var report={"cases":reports,"failures":failures,"scope":"Actual frozen game camera profiles,each dedicated ground/sea/arms material sourceIBL individually disabled/enabled afterservice update;othermaterials heldon,rawHDR contribution. Not full original image parity,haze exactness or multi-lighttotalclamp."};FileAccess.open("res://evidence/special-ibl-runtime-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
