extends SceneTree
var game
var frame=0
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=false
func _process(_dt:float)->bool:
 if game==null:return false
 frame+=1;game._process(1.0/60)
 if frame==40:call_deferred("finish")
 return false
func finish()->void:
 var failures=[]
 if game.game_ui.settings.quality!="auto" or game.render_quality.current!="high":failures.append("isolated auto preset")
 if game.post_pipeline.world_port.size!=Vector2i(960,540) or game.post_pipeline.weapon_port.size!=Vector2i(960,540):failures.append("cold auto render size")
 var report={"frames":frame,"failures":failures,"window_size":[root.size.x,root.size.y],"world_size":[game.post_pipeline.world_port.size.x,game.post_pipeline.world_port.size.y],"scope":"Cold auto/high startup at physical 960x540, isolated settings via --flow-preview; not hardware-based automatic preset selection."}
 FileAccess.open("res://evidence/quality-startup.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
