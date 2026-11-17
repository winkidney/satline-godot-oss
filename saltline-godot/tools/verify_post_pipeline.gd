extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var owner=Node3D.new();root.add_child(owner)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;owner.get_world_3d().environment=environment
 var camera=Camera3D.new();camera.position.z=2;owner.add_child(camera);camera.current=true;camera.cull_mask=0
 var pipeline=SaltlinePostPipeline.new();pipeline.setup_world(owner,camera)
 var weapon=SubViewport.new();weapon.world_3d=owner.get_world_3d();weapon.transparent_bg=true;weapon.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(weapon)
 var view=Camera3D.new();view.position.z=2;view.cull_mask=2;weapon.add_child(view);view.current=true;var env=environment.duplicate();env.background_mode=Environment.BG_CLEAR_COLOR;view.environment=env
 var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,blend_premul_alpha,cull_disabled,depth_draw_never;void fragment(){ALBEDO=vec3(8.0,.1,2.0);ALPHA=.25;}"
 var material=ShaderMaterial.new();material.shader=shader;var mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(100,100);mesh.layers=2;mesh.material_override=material;owner.add_child(mesh)
 pipeline.setup(weapon);pipeline.set_auto_exposure(false)
 for viewport in [pipeline.world_port,weapon,pipeline.scene_port,pipeline.ldr_port]:viewport.size=Vector2i(64,64)
 pipeline.down[0].size=Vector2i(32,32);pipeline.down[1].size=Vector2i(16,16);pipeline.down_materials[0].set_shader_parameter("uTexel",Vector2.ONE/64);pipeline.down_materials[1].set_shader_parameter("uTexel",Vector2.ONE/32)
 for pair in [["uGrain",0.0],["uDither",0.0],["uFxaa",0.0],["uSharpen",0.0],["uTexel",Vector2.ONE/64]]:pipeline.final_material.set_shader_parameter(pair[0],pair[1])
 var final_port=SubViewport.new();final_port.size=Vector2i(64,64);final_port.disable_3d=true;final_port.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(final_port);var final_rect=ColorRect.new();final_rect.size=Vector2(64,64);final_rect.material=pipeline.final_material;final_port.add_child(final_rect)
 for frame in 3:await process_frame
 print({"scene_rect":pipeline.scene_port.get_child(0).size,"down0_rect":pipeline.down[0].get_child(0).size,"down1_rect":pipeline.down[1].get_child(0).size,"down0_src":pipeline.down_materials[0].get_shader_parameter("tSrc").get_size(),"down1_src":pipeline.down_materials[1].get_shader_parameter("tSrc").get_size()})
 var failures=[];var maximum=0.0;var samples=[]
 for index in 12:
  var background=Color.RED if index%2==0 else Color.GREEN;environment.background_color=background
  await RenderingServer.frame_post_draw
  var scene=pipeline.scene_port.get_texture().get_image().get_pixel(32,32);var down=pipeline.down[1].get_texture().get_image().get_pixel(8,8)
  var expected=Vector3(8,.1,2)+Vector3(background.r,background.g,background.b)*.75
  var actual=Vector3(scene.r,scene.g,scene.b);var filtered=Vector3(down.r,down.g,down.b)
  var ldr=pipeline.ldr_port.get_texture().get_image().get_pixel(32,32);var displayed=final_port.get_texture().get_image().get_pixel(32,32)
  var alpha_error=absf(ldr.a-(ldr.r*.299+ldr.g*.587+ldr.b*.114));var display_error=Vector3(displayed.r-ldr.r,displayed.g-ldr.g,displayed.b-ldr.b).length()
  if alpha_error>.004 or absf(displayed.a-1)>.001 or display_error>.007:failures.append({"frame":index,"alpha_error":alpha_error,"display_error":display_error,"ldr_alpha":ldr.a})
  var error=maxf((actual-expected).length(),(filtered-expected).length())
  var bloom=pipeline.up[0].get_texture().get_image().get_pixel(16,16)
  var streak=pipeline.streak[1].get_texture().get_image().get_pixel(8,8)
  var expected_streak=Vector3(maxf(expected.x-2.2,0),maxf(expected.y-2.2,0),maxf(expected.z-2.2,0))
  error=maxf(error,(Vector3(bloom.r,bloom.g,bloom.b)-expected).length())
  error=maxf(error,(Vector3(streak.r,streak.g,streak.b)-expected_streak).length());maximum=maxf(maximum,error)
  if error>.025:failures.append(index)
  samples.append({"frame":index,"scene":[scene.r,scene.g,scene.b],"down1":[down.r,down.g,down.b],"bloom":[bloom.r,bloom.g,bloom.b],"streak":[streak.r,streak.g,streak.b],"expected":[expected.x,expected.y,expected.z],"error":error,"ldr":[ldr.r,ldr.g,ldr.b,ldr.a],"luminance_alpha_error":alpha_error,"final_display_error":display_error})
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
 root.size=Vector2i(960,540)
 await process_frame
 await RenderingServer.frame_post_draw
 var resized=Vector2i(owner.get_viewport().get_visible_rect().size);var half=pipeline._down_size(resized,0)
 var resize_ok=resized==Vector2i(960,540) and pipeline.ao_scene.size==resized and pipeline.ao_ports[0].size==half and pipeline.combined_depth.output.get_size()==Vector2(resized) and pipeline.half_depth.output.get_size()==Vector2(half)
 if not resize_ok:failures.append("default AO pipeline resize failed")
 var resized_image=pipeline.ao_scene.get_texture().get_image();var resized_color=resized_image.get_pixel(resized.x/2,resized.y/2)
 if (Vector3(resized_color.r,resized_color.g,resized_color.b)-Vector3(8,.85,2)).length()>.01:failures.append("resize same-frame HDR source mismatch")
 var report={"resize":{"size":[resized.x,resized.y],"half":[half.x,half.y],"passed":resize_ok},"frames":12,"failures":failures,"maximum_error":maximum,"samples":samples,"scope":"Actual independent HDR world/transparent weapon to premultiplied scene, six down levels, five up levels and two streak passes. Alternating red/green with full-frame radiance8 weapon verifies same-frame producer ordering through the complete graph; constant-field bloom energy and exposure threshold2.2 tested. Also verifies tk RGBA8 intermediate stores luminance alpha and nk diagnostic identity preserves RGB with opaque display output; filtering/noise disabled only in this identity probe. This does not prove nonuniform spatial kernels or dirt fidelity. Camera transform assertion executed in setup; now includes originalAO composite before down and actualroot-window resize of combinedR32F/halfR32F/AO/scene. Constant weapon bypass field is not nonuniform AO equivalence proof."}
 var file=FileAccess.open("res://evidence/post-pipeline-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures,"maximum_error":maximum,"first":samples[0]}));pipeline.dispose();owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
