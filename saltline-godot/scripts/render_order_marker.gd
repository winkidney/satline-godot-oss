extends CompositorEffect
var trace
var label=""
func _init()->void:effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
func _render_callback(kind:int,_data:RenderData)->void:
 if kind==EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:trace.record(label)
