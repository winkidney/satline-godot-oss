extends RefCounted
var timing=preload("res://scripts/css_transition_timing.gd").new()
var clock=0.0
var initial=0.0
var value=0.0
func _init(duration:float=.3)->void:
 timing.duration=duration;timing.reset(0.0,0.0)
func reset(new_value:float)->void:
 initial=new_value;value=new_value;timing.reset(new_value,clock)
func set_target(on:bool,duration:float=-1)->void:
 if duration>=0:timing.duration=duration
 var current=lerpf(initial,float(timing.target),timing.progress(clock))
 if timing.retarget(1.0 if on else 0.0,current,clock):initial=current
 value=current
func advance(dt:float)->float:
 clock+=dt;value=lerpf(initial,float(timing.target),timing.progress(clock));return value
