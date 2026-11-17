extends CompositorEffect
var mutex=Mutex.new()
var format=-1
var calls=0
func _init()->void:
 effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT;access_resolved_depth=false;access_resolved_color=false
func _render_callback(kind:int,data:RenderData)->void:
 if kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null:return
 var name="depth_msaa" if buffers.has_texture("render_buffers","depth_msaa") else "depth"
 var value=buffers.get_texture_format("render_buffers",name).format
 mutex.lock();format=value;calls+=1;mutex.unlock()
func snapshot()->Dictionary:
 mutex.lock();var result={"format":format,"calls":calls};mutex.unlock();return result
