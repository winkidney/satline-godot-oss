extends SceneTree
func _initialize()->void:call_deferred("run")
func _quad(width:float,height:float,skin:bool)->ArrayMesh:
 var primitive=QuadMesh.new();primitive.size=Vector2(width,height);var arrays=primitive.surface_get_arrays(0)
 if skin:
  var count=arrays[Mesh.ARRAY_VERTEX].size();var bones=PackedInt32Array();bones.resize(count*4);var weights=PackedFloat32Array();weights.resize(count*4)
  for i in count:weights[i*4]=1.0
  arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh
func run()->void:
 var owner=Node3D.new();root.add_child(owner);root.disable_3d=true;var scene=SaltlineSourceScene.new();owner.add_child(scene)
 scene.source={"materials":[{"id":"double","props":{"side":2,"alphaTest":0.0}}]};scene.geometry_records["quad"]={"groups":[]}
 var cfg=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/sun-shadow-camera.json"));var camera_world=scene._transform(cfg.cameraWorld)
 var group=Node3D.new();scene.add_child(group);group.global_transform=camera_world*Transform3D(Basis.IDENTITY,Vector3(-.25*cfg.width,.2*cfg.height,-(cfg.near+.4*(cfg.far-cfg.near))))
 var skeleton=Skeleton3D.new();group.add_child(skeleton);skeleton.add_bone("root");skeleton.set_bone_rest(0,Transform3D.IDENTITY);var skin=Skin.new();skin.add_bind(0,Transform3D.IDENTITY)
 var source_mesh=MeshInstance3D.new();source_mesh.mesh=_quad(cfg.width*.08,cfg.height*.10,true);group.add_child(source_mesh);source_mesh.skin=skin;source_mesh.skeleton=source_mesh.get_path_to(skeleton);source_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;source_mesh.layers=1;source_mesh.set_meta("source_id","skin")
 var multi=MultiMeshInstance3D.new();multi.multimesh=MultiMesh.new();multi.multimesh.transform_format=MultiMesh.TRANSFORM_3D;multi.multimesh.mesh=_quad(cfg.width*.06,cfg.height*.1,false);multi.multimesh.instance_count=2;scene.add_child(multi);multi.global_transform=camera_world*Transform3D(Basis.IDENTITY,Vector3(.15*cfg.width,-.2*cfg.height,-(cfg.near+.6*(cfg.far-cfg.near))));multi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;multi.layers=1;multi.set_meta("source_id","multi")
 for id in ["skin","multi"]:scene.records[id]={"id":id,"castShadow":true,"layers":1,"geometry":"quad","materials":["double"]}
 var shadow=SaltlineSunShadowPass.new();shadow.setup(owner,scene,128);var offsets=[0.0,.08,-.04,.12,.02,-.06,.04,0.0];var multi_offsets=[-.1,.02,.06,-.06,.1,.0,-.05,.03];var last_skin=0.0;var last_multi=0.0;var failures=[];var snapshots=[]
 for frame in offsets.size():
  skeleton.set_bone_pose_position(0,Vector3(offsets[frame]*cfg.width,0,0));skeleton.force_update_all_bone_transforms()
  for instance in 2:multi.multimesh.set_instance_transform(instance,Transform3D(Basis.IDENTITY,Vector3((multi_offsets[frame]+instance*.12)*cfg.width,0,0)))
  shadow.update()
  if frame%2==0:last_skin=.25+offsets[frame];last_multi=.71+multi_offsets[frame]
  await RenderingServer.frame_post_draw
  var image=shadow.depth.output.get_image();var sums=[0.0,0.0];var counts=[0,0]
  for y in image.get_height():
   for x in image.get_width():
    if image.get_pixel(x,y).r<.99999:
     var region=0 if y<64 else 1;sums[region]+=(x+.5)/128.0;counts[region]+=1
  var centroids=[sums[0]/maxi(counts[0],1),sums[1]/maxi(counts[1],1)]
  if counts[0]==0 or counts[1]==0 or absf(centroids[0]-last_skin)>1.0/128 or absf(centroids[1]-last_multi)>1.0/128:failures.append({"frame":frame,"centroids":centroids,"expected":[last_skin,last_multi],"pixels":counts})
  snapshots.append({"frame":frame,"updated":frame%2==0,"centroids":centroids,"expected":[last_skin,last_multi],"pixels":counts})
 var report={"failures":failures,"snapshots":snapshots,"casters":shadow.report,"updates":shadow.updates,"scope":"Actual independentShadow World3D proxy shares live Skin/Skeleton3D acrossworlds and live MultiMesh instancebuffer. Nonperiodic bone/instance offsets, original every-other-renderframe update with oddframes holding previousGPU map; pixelcentroid tolerance1/128. Controlled onebone plane/twoinstances, not fullsource148caster fidelity."};var file=FileAccess.open("res://evidence/sun-shadow-animation-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));shadow.dispose()
 for frame in 3:await process_frame
 owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
