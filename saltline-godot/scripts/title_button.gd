extends Button
var primary=false
var segmented=false
var panel_segmented=false
var selected=false
var pixels=15
var tracking=3.3
var focus_visible=true
var source_font:Font
var color_transition=preload("res://scripts/css_color_transition.gd").new()
var render_colors=[]
func configure(is_primary:bool)->void:
 primary=is_primary;pixels=18 if primary else 15;tracking=pixels*(.3 if primary else .22)
 source_font=load("res://assets/fonts/barlow-condensed-600.ttf").duplicate();source_font.oversampling=1
 for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_disabled_color","font_focus_color"]:add_theme_color_override(state,Color.TRANSPARENT)
 add_theme_font_override("font",source_font);add_theme_font_size_override("font_size",pixels)
 color_transition.reset(state_colors(),_clock())
func _clock()->float:return Time.get_ticks_usec()/1000000.0
func configure_segmented(in_panel:bool=false)->void:segmented=true;panel_segmented=in_panel;pixels=13 if in_panel else 12;tracking=pixels*.16;add_theme_font_size_override("font_size",pixels);queue_redraw()
func configure_small()->void:pixels=12;tracking=pixels*.22;add_theme_font_size_override("font_size",pixels);queue_redraw()
func set_selected(value:bool)->void:selected=value;z_index=1 if segmented and selected else 0;queue_redraw()
func show_keyboard_focus()->void:focus_visible=true;queue_redraw()
func _gui_input(event:InputEvent)->void:
 if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:focus_visible=false;queue_redraw()
 elif event is InputEventKey and event.pressed:focus_visible=true;queue_redraw()
func state_colors()->Array:
 var bone=Color("e8e4da");var ink=Color("0b0d0f");var signal_color=Color("ffb347")
 var fill=Color(ink,0.0 if panel_segmented else .45 if segmented else .55);var border=Color(bone,.35 if segmented else .42);var color=Color(bone,.64) if segmented else bone
 if primary:fill=Color("ffc977") if is_hovered() else signal_color;border=fill;color=ink
 elif segmented:
  if selected:fill=bone;border=bone;color=ink
  elif is_hovered():color=bone
 else:
  if is_hovered():fill=Color(bone,.12);border=bone
  if is_pressed():fill=Color(bone,.22)
 return [fill,border,color]
func _process(_dt:float)->void:
 var now=_clock();var state=state_colors()
 if segmented:render_colors=state
 else:color_transition.set_target(state,now);render_colors=color_transition.sample(now)
 queue_redraw()
func _draw()->void:
 if source_font==null:return
 var colors=render_colors if not render_colors.is_empty() else state_colors();var fill:Color=colors[0];var border:Color=colors[1];var color:Color=colors[2]
 var bone=Color("e8e4da");var signal_color=Color("ffb347")
 draw_rect(Rect2(Vector2.ZERO,size),fill);draw_rect(Rect2(Vector2(.5,.5),size-Vector2.ONE),border,false,1)
 if has_focus() and focus_visible:draw_rect(Rect2(Vector2(-4,-4),size+Vector2(8,8)),bone if primary else signal_color,false,2)
 var width=source_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+text.length()*tracking
 var start=(size.x-width)*.5+(2 if primary else 0)
 var baseline=(size.y-source_font.get_height(pixels))*.5+source_font.get_ascent(pixels)+(.5 if segmented else 1)
 for i in text.length():
  var x=start+source_font.get_string_size(text.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+i*tracking
  draw_string(source_font,Vector2(x,baseline),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
