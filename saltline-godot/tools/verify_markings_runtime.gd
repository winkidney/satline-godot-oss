extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);RenderingServer.force_draw(false)
 var source=game.source_scene;var material=source.materials["1f35ff0a-2a7c-4d04-a2ef-c088ea8b8a8d"];var failures=[];var reports=[]
 if material.get_shader_parameter("source_markings_bump")!=true:failures.append("original markings patch not bound")
 var viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;camera.far=4;viewport.add_child(camera);camera.current=true
 var mesh=MeshInstance3D.new();viewport.add_child(mesh);mesh.set_instance_shader_parameter("source_ibl_viewmodel",true)
 for record in source.source.nodes:
  if "1f35ff0a-2a7c-4d04-a2ef-c088ea8b8a8d" not in record.get("materials",[]):continue
  mesh.mesh=source.source_nodes[record.id].mesh;var bounds=mesh.mesh.get_aabb();mesh.position=-bounds.get_center();camera.size=maxf(bounds.size.y,bounds.size.z)*1.3;camera.position=Vector3(.5,.08,.12);camera.look_at(Vector3.ZERO,Vector3.UP);var images=[]
  for enabled in [false,true]:
   material.set_shader_parameter("source_markings_bump",enabled)
   for warm in 3:await process_frame;RenderingServer.force_draw(false)
   images.append(viewport.get_texture().get_image())
  var changed=0;var maximum=0.0;var occupied=0
  for y in images[0].get_height():
   for x in images[0].get_width():
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta)
    if maxf(b.r,maxf(b.g,b.b))>.001:occupied+=1
    if delta>.00001:changed+=1
  if occupied<20 or changed<20:failures.append("marking mesh bump not visible "+record.id)
  reports.append({"id":record.id,"occupied_pixels":occupied,"changed_hdr_pixels":changed,"maximum_rgb_difference":maximum})
  if reports.size()==1:
   for index in 2:
    var image=images[index].duplicate();image.convert(Image.FORMAT_RGB8);image.save_png("res://evidence/markings-bump-on.png" if index==1 else "res://evidence/markings-bump-off.png")
 if reports.size()!=3:failures.append("expected three original markings meshes")
 var report={"meshes":reports,"failures":failures,"scope":"Actual original markings factory binding andthree original geometry+UV+texture meshes, production alpha shader with original PMREM IBL, isolated orthographic side view. Toggle original -alpha*50micron height, HDR contribution. Bump core mathematical proof is separate32case test; polygon offset andfull source perspective composite not claimed."};FileAccess.open("res://evidence/markings-runtime-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));mesh.mesh=null;viewport.queue_free();await process_frame;game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
