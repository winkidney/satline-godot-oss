extends SaltlineSolarDepthBridge
var attachment_format=-1
func _render_callback(kind:int,data:RenderData)->void:
 super._render_callback(kind,data)
 if kind!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:return
 var buffers=data.get_render_scene_buffers() as RenderSceneBuffersRD
 if buffers==null:return
 var texture=buffers.get_texture_format("render_buffers","depth_msaa" if buffers.has_texture("render_buffers","depth_msaa") else "depth")
 _mutex.lock();attachment_format=texture.format;_mutex.unlock()
func format_snapshot()->int:
 _mutex.lock();var value=attachment_format;_mutex.unlock();return value
