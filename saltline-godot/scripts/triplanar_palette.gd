extends RefCounted
var texture:ImageTexture
var image:Image
var bindings=[]
var listeners=[]
var report={"meshes":0,"rows":0,"invalid_bindings":[]}
func _init()->void:
 image=Image.create(4,1,false,Image.FORMAT_RGBAF)
 for column in 4:image.set_pixel(column,0,Color(1 if column==0 else 0,1 if column==1 else 0,1 if column==2 else 0,1 if column==3 else 0))
 texture=ImageTexture.create_from_image(image)
func setup(scene:SaltlineSourceScene)->void:
 var offset=0;var records={}
 for record in scene.source.materials:records[record.id]=record
 for binding in scene.skin_bindings:
  var record=scene.records[binding.mesh];var tri=false
  for material_id in record.materials:
   if records[material_id].props.get("defines",{}).has("SL_TRIPLANAR"):tri=true
  if not tri:continue
  var node:MeshInstance3D=scene.source_nodes[binding.mesh];bindings.append({"node":node,"skeleton":binding.skeleton,"skin":node.skin,"base":offset});node.set_instance_shader_parameter("source_tri_skinned",true);node.set_instance_shader_parameter("source_tri_palette_base",offset);offset+=node.skin.get_bind_count()
 image=Image.create(4,maxi(offset,1),false,Image.FORMAT_RGBAF);texture.set_image(image)
 for binding in bindings:_write(binding)
 texture.update(image)
 var connected={}
 for binding in bindings:
  var skeleton:Skeleton3D=binding.skeleton
  if connected.has(skeleton.get_instance_id()):continue
  connected[skeleton.get_instance_id()]=true;var callback=_updated.bind(skeleton);skeleton.skeleton_updated.connect(callback);listeners.append([weakref(skeleton),callback])
 report.meshes=bindings.size();report.rows=offset
func _write(binding:Dictionary)->void:
 var node:MeshInstance3D=binding.node;var skeleton:Skeleton3D=binding.skeleton;var skin:Skin=binding.skin;var to_mesh=node.global_transform.affine_inverse()*skeleton.global_transform
 for slot in skin.get_bind_count():
  var name=skin.get_bind_name(slot);var bone=skeleton.find_bone(name) if not str(name).is_empty() else skin.get_bind_bone(slot)
  if bone<0:report.invalid_bindings.append(str(name));continue
  var pose=to_mesh*skeleton.get_bone_global_pose(bone)*skin.get_bind_pose(slot);var row=binding.base+slot
  image.set_pixel(0,row,Color(pose.basis.x.x,pose.basis.x.y,pose.basis.x.z,0));image.set_pixel(1,row,Color(pose.basis.y.x,pose.basis.y.y,pose.basis.y.z,0));image.set_pixel(2,row,Color(pose.basis.z.x,pose.basis.z.y,pose.basis.z.z,0));image.set_pixel(3,row,Color(pose.origin.x,pose.origin.y,pose.origin.z,1))
func _updated(skeleton:Skeleton3D)->void:
 for binding in bindings:
  if binding.skeleton==skeleton:_write(binding)
 texture.update(image)
func dispose()->void:
 for listener in listeners:
  var skeleton=listener[0].get_ref()
  if skeleton!=null and skeleton.skeleton_updated.is_connected(listener[1]):skeleton.skeleton_updated.disconnect(listener[1])
 listeners.clear();bindings.clear()
