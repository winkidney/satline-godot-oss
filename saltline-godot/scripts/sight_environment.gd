class_name SaltlineSightEnvironment
extends RefCounted

var peak=0.0
var value=1.0

# Original ME.onBeforeRender; intentionally per rendered frame, not dt based.
func update(environment_intensity:float)->float:
 var current=environment_intensity if environment_intensity!=0 else 1.0
 if current>peak:peak=current
 var target=clampf((current/peak-.55)/.4,0,1)
 value+=(target-value)*.12
 return value
