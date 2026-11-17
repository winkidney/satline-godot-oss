extends SceneTree
signal samples_received
var read_values=[]
var mirrored=false
var quantize4=false
var projection_flip=false
var engine_origin=false
func _initialize()->void:call_deferred("run")
func _accept(a:Array,b:Array)->void:read_values=[a,b];samples_received.emit()
func _read_gpu(a:SaltlineDepthSamplesBridge,b:SaltlineDepthSamplesBridge,pixel:Vector2i)->void:
 var rd=RenderingServer.get_rendering_device();var wa=[];var wb=[]
 for sample in a.samples:wa.append(rd.texture_get_data(a.output_rd,sample).to_float32_array()[pixel.y*a.output_size.x+pixel.x])
 for sample in b.samples:wb.append(rd.texture_get_data(b.output_rd,sample).to_float32_array()[pixel.y*b.output_size.x+pixel.x])
 call_deferred("_accept",wa,wb)
func port(owner:Node3D,layer:int)->Dictionary:
 var viewport=SubViewport.new();viewport.size=Vector2i(16,16);viewport.msaa_3d=Viewport.MSAA_4X;viewport.world_3d=owner.get_world_3d();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport)
 if engine_origin:RenderingServer.viewport_set_source_raster_y_up(viewport.get_viewport_rid(),true)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.near=.01;camera.far=1.01;camera.cull_mask=layer;viewport.add_child(camera);camera.current=true
 if mirrored:camera.basis=Basis(Vector3.RIGHT,-Vector3.UP,Vector3.BACK)
 var effect=SaltlineDepthSamplesBridge.new();var compositor=Compositor.new();compositor.compositor_effects=[effect];camera.compositor=compositor;return {"viewport":viewport,"camera":camera,"effect":effect}
func material()->Material:
 if projection_flip:
  var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void vertex(){PROJECTION_MATRIX[1][1]=-PROJECTION_MATRIX[1][1];}void fragment(){ALBEDO=vec3(1);}";var value=ShaderMaterial.new();value.shader=shader;return value
 var value=StandardMaterial3D.new();value.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;value.cull_mode=BaseMaterial3D.CULL_DISABLED;return value
func run()->void:
 engine_origin="--engine-origin" in OS.get_cmdline_user_args()
 projection_flip="--projection" in OS.get_cmdline_user_args();mirrored="--mirror" in OS.get_cmdline_user_args();quantize4="--quantize4" in OS.get_cmdline_user_args()
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/msaa-depth-reference.json"));var owner=Node3D.new();root.add_child(owner);var world=port(owner,1);var weapon=port(owner,2)
 var world_mesh=MeshInstance3D.new();world_mesh.mesh=QuadMesh.new();world_mesh.mesh.size=Vector2(2,2);world_mesh.position.z=-.81;world_mesh.layers=1;world_mesh.material_override=material();owner.add_child(world_mesh)
 var weapon_mesh=MeshInstance3D.new();weapon_mesh.layers=2;weapon_mesh.material_override=material();owner.add_child(weapon_mesh)
 for frame in 4:await process_frame
 var combined_bridge=SaltlineCombinedDepthBridge.new();combined_bridge.world_samples=world.effect;combined_bridge.weapon_samples=weapon.effect;combined_bridge.flip_y=mirrored or projection_flip or engine_origin;combined_bridge.prepare_size(Vector2i(16,16))
 var effects=weapon.camera.compositor.compositor_effects;effects.append(combined_bridge);weapon.camera.compositor.compositor_effects=effects
 var reports=[];var failures=[];var partial=0
 for index in reference.cases.size():
  var sample=reference.cases[index];var edge=2*(8+float(sample.fraction))/16-1;var slope=1.0 if sample.axis=="diag" else -1.0 if sample.axis=="anti" else .37 if sample.axis=="slope" else 0.0
  var xy=[]
  if sample.axis=="y":xy=[Vector2(-1,-1),Vector2(1,-1),Vector2(1,edge),Vector2(-1,-1),Vector2(1,edge),Vector2(-1,edge)]
  else:xy=[Vector2(-1,-1),Vector2(edge-slope,-1),Vector2(edge+slope,1),Vector2(-1,-1),Vector2(edge+slope,1),Vector2(-1,1)]
  var vertices=PackedVector3Array()
  for p in xy:
   if quantize4:p=(p+Vector2.ONE)*128.0;p=Vector2(roundf(p.x),roundf(p.y))/128.0-Vector2.ONE
   vertices.append(Vector3(p.x,p.y,-.41))
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);weapon_mesh.mesh=mesh
  await RenderingServer.frame_post_draw
  if not combined_bridge.is_ready_for(Vector2i(16,16)):failures.append({"case":index,"combined_size_not_ready":true})
  var gpu_combined=combined_bridge.output.get_image().get_pixel(8,7).r
  RenderingServer.call_on_render_thread(_read_gpu.bind(world.effect,weapon.effect,Vector2i(8,8 if mirrored or projection_flip or engine_origin else 7)));await samples_received
  if read_values[0].size()!=4 or read_values[1].size()!=4:failures.append("Expected four captured samples");break
  var combined=[];var coverage=0
  for s in 4:
   var dw=1-float(read_values[0][s]);var zv=float(read_values[1][s]);combined.append(minf(dw,.05*(1-zv)) if zv>0 else dw);coverage+=int(zv>0)
   if absf(dw-.8)>.000002 or (zv>0 and absf(zv-.6)>.000002):failures.append({"case":index,"unexpected_depth":[dw,zv]})
  if absf(gpu_combined-combined[0])>.000002:failures.append({"case":index,"GPU_combined":gpu_combined,"CPU_selected_prediction":combined[0]})
  if coverage>0 and coverage<4:partial+=1
  reports.append({"case":index,"axis":sample.axis,"fraction":sample.fraction,"original_coverage":sample.coverage,"native_coverage":coverage/4.0,"original_depth":sample.depth,"world_reverse":read_values[0],"weapon_reverse":read_values[1],"combined":combined,"gpu_combined_selected":gpu_combined})
 var report={"engine_origin":engine_origin,"projection_y_flipped":projection_flip,"mirrored_camera":mirrored,"vertex_quantized_to_4_subpixel_bits":quantize4,"failures":failures,"cases":reports,"partial_pixels":partial,"samples":world.effect.samples,"scope":"Actual native MSAA4 world/weapon reverse-Z samples captured independently before default resolve to R32F array layers; same orthographic clip geometry sweep as originalThree reference. Per-sample candidate min(1-worldZ,.05*(1-weaponZ)) only on weapon-covered samples. Reports sample-location/resolve comparison, not a claim of full backend edge equivalence or defaultAO integration."}
 var file=FileAccess.open("res://evidence/depth-samples-engine-origin-verification.json" if engine_origin else "res://evidence/depth-samples-projection-verification.json" if projection_flip else "res://evidence/depth-samples-mirrored-quantized-verification.json" if mirrored and quantize4 else "res://evidence/depth-samples-mirrored-verification.json" if mirrored else "res://evidence/depth-samples-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures,"cases":reports.size(),"partial_pixels":partial,"samples":world.effect.samples}))
 world.camera.compositor=null;weapon.camera.compositor=null;world.effect.dispose();weapon.effect.dispose();combined_bridge.dispose()
 for frame in 3:await process_frame
 owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
