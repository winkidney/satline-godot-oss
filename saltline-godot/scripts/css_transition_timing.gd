extends RefCounted
# Zero-delay transitions used by Saltline CSS. Reversal follows CSS Transitions 1.
var duration=.12
var respects_motion_preference=true
var curve=Vector4(.25,.1,.25,1)
var started_at=0.0
var active_duration=0.0
var shortening=1.0
var target:Variant
var reversing_start:Variant
func reset(value:Variant,now:float)->void:
 target=value;reversing_start=value;started_at=now;active_duration=0;shortening=1
func progress(now:float)->float:
 if active_duration<=0:return 1.0
 var t=clampf((now-started_at)/active_duration,0,1)
 return SaltlineCombatFeedback.bezier(t,curve.x,curve.y,curve.z,curve.w) if t<1 else 1.0
func retarget(value:Variant,current:Variant,now:float)->bool:
 if value==target:return false
 var running=active_duration>0 and now<started_at+active_duration
 var factor=1.0
 if running and value==reversing_start:
  factor=clampf(absf(progress(now)*shortening+1.0-shortening),0,1)
  reversing_start=target
 else:reversing_start=current
 var seconds=preload("res://scripts/motion_preference.gd").duration(duration) if respects_motion_preference else duration
 target=value;started_at=now;shortening=factor;active_duration=seconds*factor if current!=value else 0.0
 return true
