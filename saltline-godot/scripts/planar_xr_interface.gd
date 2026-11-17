extends XRInterfaceExtension
# Experimental mono projection transport, used only by the controlled reflection probe.
var initialized=false
var mutex=Mutex.new()
var snapshot={"pose":Transform3D.IDENTITY,"projection":PackedFloat64Array(),"size":Vector2(256,128)}
var projection_calls=0
func publish(pose:Transform3D,projection:Projection,size:Vector2i)->void:
 var values=PackedFloat64Array()
 for column in 4:
  for row in 4:values.append(projection[column][row])
 mutex.lock();snapshot={"pose":pose,"projection":values,"size":Vector2(size)};mutex.unlock()
func _get_name()->StringName:return &"SaltlinePlanarProjectionProbe"
func _get_capabilities()->int:return XRInterface.XR_MONO
func _initialize()->bool:initialized=true;return true
func _is_initialized()->bool:return initialized
func _uninitialize()->void:initialized=false
func _get_view_count()->int:return 1
func _get_render_target_size()->Vector2:
 mutex.lock();var value=snapshot.size;mutex.unlock();return value
func _get_camera_transform()->Transform3D:
 mutex.lock();var value=snapshot.pose;mutex.unlock();return value
func _get_transform_for_view(_view:int,_cam_transform:Transform3D)->Transform3D:
 mutex.lock();var value=snapshot.pose;mutex.unlock();return value
func _get_projection_for_view(_view:int,_aspect:float,_z_near:float,_z_far:float)->PackedFloat64Array:
 mutex.lock();projection_calls+=1;var value=snapshot.projection;mutex.unlock();return value
func _get_color_texture()->RID:return RID()
func _get_depth_texture()->RID:return RID()
func _pre_draw_viewport(_render_target:RID)->bool:return initialized
func _post_draw_viewport(_render_target:RID,_screen_rect:Rect2)->void:pass
