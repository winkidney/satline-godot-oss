extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var group=Node3D.new();viewport.add_child(group)
 var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();group.add_child(camera);camera.position=Vector3(0,0,3);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true
 var skeleton=Skeleton3D.new();group.add_child(skeleton)
 for i in 3:skeleton.add_bone("bone%d"%i);skeleton.set_bone_rest(i,Transform3D.IDENTITY)
 var pose=Transform3D(Basis(Vector3.UP,.37),Vector3(.2,.4,.1));skeleton.set_bone_pose(2,pose);skeleton.force_update_all_bone_transforms()
 var primitive=QuadMesh.new();primitive.size=Vector2(2,2);var arrays=primitive.surface_get_arrays(0);var rest=PackedFloat32Array();var normals=PackedFloat32Array();var bones=PackedInt32Array();var weights=PackedFloat32Array()
 for vertex in arrays[Mesh.ARRAY_VERTEX]:rest.append_array(PackedFloat32Array([vertex.x,vertex.y,vertex.z,1]));normals.append_array(PackedFloat32Array([0,0,1,0]));bones.append_array(PackedInt32Array([2,0,0,0]));weights.append_array(PackedFloat32Array([1,0,0,0]))
 arrays[Mesh.ARRAY_CUSTOM1]=rest;arrays[Mesh.ARRAY_CUSTOM2]=normals;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights;var flags=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT);var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},flags)
 var instance=MeshInstance3D.new();instance.mesh=mesh;group.add_child(instance);var skin=Skin.new()
 for i in 3:skin.add_bind(i,Transform3D.IDENTITY)
 instance.skin=skin;instance.skeleton=instance.get_path_to(skeleton)
 var material=ShaderMaterial.new();var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled;uniform mat4 expected_pose;uniform int mode;varying vec3 value;void vertex(){if(mode==0)value=vec3(float(BONE_INDICES.x),BONE_WEIGHTS.x,0.0);else if(mode==1)value=abs(VERTEX-(expected_pose*vec4(CUSTOM1.xyz,1.0)).xyz);else value=abs(normalize(NORMAL)-normalize(mat3(expected_pose)*CUSTOM2.xyz));POSITION=vec4(CUSTOM1.xy,.5,1.0);}void fragment(){ALBEDO=value;}";material.shader=shader;material.set_shader_parameter("expected_pose",Projection(pose));instance.material_override=material
 var reports=[];var failures=[]
 for mode in 3:
  material.set_shader_parameter("mode",mode)
  for warm in 4:await RenderingServer.frame_post_draw
  var image=viewport.get_texture().get_image();var maximum=0.0
  for y in range(4,60):
   for x in range(4,60):
    var c=image.get_pixel(x,y);var error=maxf(absf(c.r-2),absf(c.g-1)) if mode==0 else maxf(c.r,maxf(c.g,c.b));maximum=maxf(maximum,error)
  if maximum>.0002:failures.append({"mode":mode,"maximum_error":maximum})
  reports.append({"mode":mode,"maximum_error":maximum})
 var report={"cases":reports,"failures":failures,"scope":"Actual MeshInstance3D Skeleton3D skin compute plus spatial vertex shader: original bone index2/weight1 accessible, VERTEX/NORMAL already posed, CUSTOM1/2 retain rest inputs.64HDR target, interior3136samples eachmode. Onebone rigidrotation+translation, not original18actor axis parity."};var file=FileAccess.open("res://evidence/skin-vertex-inputs-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
