extends "res://scripts/title_button.gd"
func configure_tab(active:bool)->void:
 configure(false);selected=active;pixels=15;tracking=3.3
 custom_minimum_size=Vector2(source_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+text.length()*tracking,44)
func _process(_dt:float)->void:queue_redraw()
func _draw()->void:
 if source_font==null:return
 var color=Color("e8e4da") if selected or is_hovered() else Color("8d9aa3")
 var baseline=14+(15-source_font.get_height(pixels))*.5+source_font.get_ascent(pixels)
 for i in text.length():
  var x=source_font.get_string_size(text.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*tracking
  draw_string(source_font,Vector2(x,baseline),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
 if selected:draw_rect(Rect2(0,size.y-3,size.x,3),Color("ffb347"))
 if has_focus() and focus_visible:draw_rect(Rect2(Vector2(-4,-4),size+Vector2(8,8)),Color("ffb347"),false,2)
