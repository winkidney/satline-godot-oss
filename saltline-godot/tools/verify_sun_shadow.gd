extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-shadow-gpu-reference.json"));var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-shadow-camera.json"))
 var owner=Node3D.new();root.add_child(owner);root.disable_3d=true
 var scene=SaltlineSourceScene.new();owner.add_child(scene);scene.source={"materials":[]};scene.geometry_records["quad"]={"groups":[]}
 var alpha=Image.create_from_data(2,2,false,Image.FORMAT_RGBA8,PackedByteArray(data.alpha));alpha.flip_y();alpha.generate_mipmaps();scene.textures["checker"]=ImageTexture.create_from_image(alpha);scene.texture_records["checker"]={"repeat":[1,1],"offset":[0,0]}
 for spec in data.cases:
  var props={"side":spec.side,"alphaTest":.5 if spec.cut else 0.0,"opacity":1.0,"map":{"$texture":"checker"} if spec.cut else null}
  scene.source.materials.append({"id":spec.name,"props":props});var record={"id":spec.name,"castShadow":true,"layers":1,"geometry":"quad","materials":[spec.name]};scene.records[spec.name]=record
  var primitive=QuadMesh.new();primitive.size=Vector2(cfg.width*.18,cfg.height*.22);var arrays=primitive.surface_get_arrays(0);var uv=arrays[Mesh.ARRAY_TEX_UV]
  for i in uv.size():uv[i].y=1-uv[i].y
  arrays[Mesh.ARRAY_TEX_UV]=uv;var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var instance=MeshInstance3D.new();instance.mesh=mesh;instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;instance.layers=1;instance.set_meta("source_id",spec.name);scene.add_child(instance);instance.global_transform=scene._transform(spec.world)
 var shadow=SaltlineSunShadowPass.new();shadow.setup(owner,scene,int(data.resolution))
 for frame in 3:shadow.update(true);await process_frame
 await RenderingServer.frame_post_draw
 var image=shadow.depth.output.get_image();var failures=[];var maximum=0.0;var mismatches=0;var covered=0
 for y in int(data.resolution):
  for x in int(data.resolution):
   var expected=float(data.depth[(y*int(data.resolution)+x)*4]);var actual=image.get_pixel(x,int(data.resolution)-1-y).r;var error=absf(actual-expected);maximum=maxf(maximum,error)
   if actual<.99999:covered+=1
   if error>.00002:
    mismatches+=1
    if failures.size()<20:failures.append({"x":x,"y":y,"actual":actual,"original":expected})
 var point_max=0.0
 for item in cfg.points:
  var world=Vector3(item.world[0],item.world[1],item.world[2]);var local=shadow.camera.global_transform.affine_inverse()*world
  var projected=Vector3(.5+local.x/cfg.width,.5+local.y/cfg.height,(-local.z-cfg.near)/(cfg.far-cfg.near));var expected=Vector3(item.shadow[0],item.shadow[1],item.shadow[2]);point_max=maxf(point_max,projected.distance_to(expected))
 if point_max>.00002:failures.append("world-to-shadow projection mismatch")
 var visual=image.duplicate();visual.convert(Image.FORMAT_RGB8);visual.save_png("res://evidence/sun-shadow-native.png");image.save_exr("res://evidence/sun-shadow-native.exr",false)
 var report={"resolution":data.resolution,"failures":failures,"pixels":int(data.resolution)*int(data.resolution),"depth_mismatches":mismatches,"covered_pixels":covered,"maximum_depth_error":maximum,"projection_points":cfg.points.size(),"maximum_projection_error":point_max,"casters":shadow.report,"format":image.get_format(),"scope":"Actual original Three shadowMap RGBA8 packed/decode vs native independent caster World3D depth+R32F export, original nonsquare fixedZM projection on64square. Tests defaultshadowSide inversion, front/back/double and asymmetricalphaTest map. CPU world-to-shadow256points separately. No source scene skin/instance/4096map or update cadence proof."}
 var file=FileAccess.open("res://evidence/sun-shadow-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));shadow.dispose()
 for frame in 3:await process_frame
 owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
