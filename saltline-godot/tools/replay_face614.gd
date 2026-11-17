extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var engine_origin="--engine-origin" in OS.get_cmdline_user_args()
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/face614-replay-input.json"))
 var port=SubViewport.new();port.size=Vector2i(1280,720);port.use_hdr_2d=true;port.msaa_3d=Viewport.MSAA_4X;port.own_world_3d=true
 if engine_origin:RenderingServer.viewport_set_source_raster_y_up(port.get_viewport_rid(),true)
 root.add_child(port)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;port.add_child(env)
 var camera=Camera3D.new();camera.position.z=1;port.add_child(camera);camera.make_current()
 var vertices=PackedVector3Array()
 for v in data.positions:vertices.append(Vector3(v[0],v[1],v[2]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_test_disabled,depth_draw_never;uniform float y_sign=-1.;uniform bool engine_origin=false;void vertex(){POSITION=vec4(VERTEX.x,VERTEX.y*(engine_origin?sign(PROJECTION_MATRIX[1][1]):y_sign),.5,1.);}void fragment(){ALBEDO=vec3(1.);}"
 var material=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("engine_origin",engine_origin)
 var node=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;port.add_child(node)
 var rows=[]
 for sign in ([1.0] if engine_origin else [-1.0,1.0]):
  material.set_shader_parameter("y_sign",sign)
  for i in 4:
   port.render_target_update_mode=SubViewport.UPDATE_ONCE;await process_frame;RenderingServer.force_draw(false)
  var image=port.get_texture().get_image();rows.append({"y_sign":sign,"weight":image.get_pixel(660,359 if sign<0 else 360).r,"format":image.get_format()})
 var report={"rows":rows,"scope":"Forward+ direct POSITION CPU NDC single triangle, MSAA4, no depth; opposite sign read at mirrored row. Not full source vertex transformation proof."}
 report["engine_origin"]=engine_origin
 if engine_origin:assert(rows[0].weight==0.25,"Engine raster origin did not recover source triangle coverage")
 FileAccess.open("res://evidence/face614-native-engine-replay.json" if engine_origin else "res://evidence/face614-native-replay.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));port.queue_free();await process_frame;quit()
