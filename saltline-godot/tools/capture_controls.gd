extends SceneTree
var game
func _initialize()->void:call_deferred("run")
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path=""
 for i in 40:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/controls-title.png")
 root.size=Vector2i(960,540)
 for i in 4:await process_frame
 if game.game_ui.title_legend.visible:await fail("Legend should be hidden below source viewport threshold");return
 root.size=Vector2i(1280,720)
 for i in 4:await process_frame
 if not game.game_ui.title_legend.visible:await fail("Legend should be visible above source viewport threshold");return
 game.game_ui.open_panel(true)
 for i in 4:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/controls-keyboard.png")
 var scroll=game.game_ui.panel.find_child("ControlTables",true,false)
 scroll.scroll_vertical=360
 for i in 4:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/controls-middle.png")
 scroll.scroll_vertical=10000
 for i in 4:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/controls-bottom.png")
 print("CONTROL_TABLE_CAPTURE_COMPLETE scroll_max=",scroll.get_v_scroll_bar().max_value)
 game._dispose_game();game.queue_free();await process_frame;quit()
func fail(message:String)->void:
 push_error(message);game._dispose_game();game.queue_free();await process_frame;quit(1)
