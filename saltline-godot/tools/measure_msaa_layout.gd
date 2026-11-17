extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var port=SubViewport.new();port.size=Vector2i(16,16);port.use_hdr_2d=true;port.msaa_3d=Viewport.MSAA_4X;port.own_world_3d=true;root.add_child(port)
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;port.add_child(environment)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.near=.1;camera.far=10;camera.position.z=1;port.add_child(camera);camera.make_current()
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(0,0,0),Vector3(1,0,0),Vector3(0,1,0),Vector3(1,1,0)]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,1,3,2])
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;void fragment(){ALBEDO=vec3(1.0);}";var material=ShaderMaterial.new();material.shader=shader
 var plane=MeshInstance3D.new();plane.mesh=mesh;plane.material_override=material;plane.position=Vector3(0,-1,0);port.add_child(plane)
 var grid=[];var format=-1
 for y in 9:
  var row=[]
  for x in 9:
   plane.scale=Vector3(maxf(.000001,x/8.0),maxf(.000001,y/8.0),1)
   port.render_target_update_mode=SubViewport.UPDATE_ONCE
   await process_frame;RenderingServer.force_draw(false)
   var image=port.get_texture().get_image();format=image.get_format();row.append(image.get_pixel(8,8).r)
  grid.append(row)
 var report={"grid":grid,"format":format,"threshold_step":.125,"origin":"bottom-left within target pixel, world XY quadrant","samples":4,"viewport":[16,16],"pixel":[8,8],"method":"Actual Forward+ geometry quadrant scan; not original scene frame proof."}
 FileAccess.open("res://evidence/weapon-studio-native-sample-layout.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"format":format,"grid":grid}));port.queue_free();await process_frame;quit()
