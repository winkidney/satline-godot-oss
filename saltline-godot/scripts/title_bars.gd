extends Control
var target=false
var amount=0.0
var start=0.0
var elapsed=.7
var initialized=false
var clock=0.0
var timing=preload("res://scripts/css_transition_timing.gd").new()
func show_title(on:bool)->void:
 if not initialized:
  initialized=true;target=on;amount=1.0 if on else 0.0;elapsed=.7
  timing.duration=.7;timing.curve=Vector4(.2,.7,.2,1);timing.reset(amount,clock);return
 if on!=target:
  amount=lerpf(start,float(timing.target),timing.progress(clock))
  timing.retarget(1.0 if on else 0.0,amount,clock)
  target=on;start=amount;elapsed=0
func update_frame(dt:float)->void:
 var physical=Vector2(get_window().size);var logical=get_viewport_rect().size
 if physical.x<=0 or physical.y<=0:return
 scale=logical/physical;size=physical
 clock+=dt;elapsed+=dt
 amount=lerpf(start,float(timing.target),timing.progress(clock))
 visible=amount>0;queue_redraw()
func _draw()->void:
 var height=clampf(size.y*.055,14,52);var shift=height*1.01*(1-amount)
 draw_rect(Rect2(0,-shift,size.x,height),Color.BLACK)
 draw_rect(Rect2(0,size.y-height+shift,size.x,height),Color.BLACK)
