extends HSlider
var focus_visible=true
func _ready()->void:
 var track=StyleBoxFlat.new();track.bg_color=Color(Color("e8e4da"),.35);track.content_margin_top=1;track.content_margin_bottom=1
 add_theme_stylebox_override("slider",track)
 for key in ["grabber_area","grabber_area_highlight","focus"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
 var image=Image.create(10,22,false,Image.FORMAT_RGBA8);image.fill(Color("ffb347"));var texture=ImageTexture.create_from_image(image)
 for key in ["grabber","grabber_highlight","grabber_disabled"]:add_theme_icon_override(key,texture)
func show_keyboard_focus()->void:focus_visible=true;queue_redraw()
func _gui_input(event:InputEvent)->void:
 if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:focus_visible=false
 elif event is InputEventKey and event.pressed:focus_visible=true
 queue_redraw()
func _draw()->void:
 if has_focus() and focus_visible:draw_rect(Rect2(Vector2(-4,-4),size+Vector2(8,8)),Color("ffb347"),false,2)
