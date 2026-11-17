extends RefCounted
var target=[]
var initial=[]
var started_at=[]
var timings=[]
var duration=.12
var respects_motion_preference=true
static func legacy(colors:Array)->Array:
 var result=[]
 for color in colors:result.append(Color(color.r,color.g,color.b,floor(color.a*255+.5)/255))
 return result
func reset(colors:Array,now:float)->void:
 target=legacy(colors);initial=target.duplicate();started_at=[];timings=[]
 for color in target:
  started_at.append(now-duration)
  var timing=preload("res://scripts/css_transition_timing.gd").new();timing.duration=duration;timing.respects_motion_preference=respects_motion_preference;timing.reset(color,now);timings.append(timing)
func set_target(colors:Array,now:float)->void:
 var next=legacy(colors)
 if target.is_empty():reset(colors,now);return
 for i in next.size():
  if next[i]==target[i]:continue
  var current=sample_color(i,now);timings[i].duration=duration;timings[i].respects_motion_preference=respects_motion_preference;timings[i].retarget(next[i],current,now)
  initial[i]=current;target[i]=next[i];started_at[i]=now
func sample(now:float)->Array:
 var result=[]
 for i in target.size():result.append(sample_color(i,now))
 return result
func sample_color(i:int,now:float)->Color:
 var p=timings[i].progress(now)
 if p>=1:return target[i]
 var a:Color=initial[i];var b:Color=target[i];var alpha=lerpf(a.a,b.a,p)
 if alpha==0:return Color.TRANSPARENT
 return Color(lerpf(a.r*a.a,b.r*b.a,p)/alpha,lerpf(a.g*a.a,b.g*b.a,p)/alpha,lerpf(a.b*a.a,b.b*b.a,p)/alpha,alpha)
