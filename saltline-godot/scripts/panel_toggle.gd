extends Button
var source_font=preload("res://assets/fonts/ibm-plex-mono-500.ttf")
var focus_visible=true
var amount=0.0
var thumb_color=Color(Color("e8e4da"),.64)
var shown_state=false
var last_clock=0.0
var motion=preload("res://scripts/css_opacity_transition.gd").new(.12)
var colors=preload("res://scripts/css_color_transition.gd").new()
func _clock()->float:return Time.get_ticks_usec()/1000000.0
func _thumb(on:bool)->Color:return Color("ffb347") if on else Color(Color("e8e4da"),.64)
func configure(on:bool)->void:
 # The original media query does not select the thumb's ::after pseudo-element.
 motion.timing.respects_motion_preference=false;colors.respects_motion_preference=false
 toggle_mode=true;button_pressed=on;shown_state=on;amount=1.0 if on else 0.0;motion.reset(amount)
 text="";custom_minimum_size=Vector2(56+source_font.get_string_size("Off",HORIZONTAL_ALIGNMENT_LEFT,-1,13).x,30)
 for key in ["normal","hover","pressed","hover_pressed","disabled","focus"]:add_theme_stylebox_override(key,StyleBoxEmpty.new())
 last_clock=_clock();colors.reset([_thumb(on)],last_clock);thumb_color=_thumb(on)
func show_keyboard_focus()->void:focus_visible=true;queue_redraw()
func _gui_input(event:InputEvent)->void:
 if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:focus_visible=false
 elif event is InputEventKey and event.pressed:focus_visible=true
 queue_redraw()
func _process(_dt:float)->void:
 var now=_clock();motion.advance(maxf(0,now-last_clock));last_clock=now
 if shown_state!=button_pressed:
  shown_state=button_pressed;motion.set_target(shown_state);colors.set_target([_thumb(shown_state)],now)
 amount=motion.value;thumb_color=colors.sample(now)[0];queue_redraw()
func _draw()->void:
 var bone=Color("e8e4da");var signal_color=Color("ffb347")
 draw_rect(Rect2(.5,4.5,43,21),signal_color if button_pressed else Color(bone,.45),false,1)
 draw_rect(Rect2(4+20*amount,8,16,14),thumb_color)
 var baseline=(30-source_font.get_height(13))*.5+source_font.get_ascent(13)
 draw_string(source_font,Vector2(56,baseline),"On" if button_pressed else "Off",HORIZONTAL_ALIGNMENT_LEFT,-1,13,bone)
 if has_focus() and focus_visible:draw_rect(Rect2(Vector2(-4,-4),size+Vector2(8,8)),signal_color,false,2)
