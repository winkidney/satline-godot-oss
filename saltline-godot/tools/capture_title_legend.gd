extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var background=ColorRect.new();background.color=Color("0b0d0f");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
 var legend=preload("res://scripts/title_legend.gd").new();root.add_child(legend)
 for i in 8:await process_frame;legend.update_layout()
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/title-legend-native.png")
 print(JSON.stringify({"position":[legend.position.x,legend.position.y],"size":[legend.size.x,legend.size.y],"glyphs":legend.data.glyphs.size(),"boxes":legend.data.boxes.size()}));legend.queue_free();background.queue_free();await process_frame;quit()
