extends RefCounted
# Original input hE/mousemove/wheel, bundle-1.js 68202, 68370–68402.
# Godot wheel factor is a notch multiplier, not browser deltaY pixels.
var dx=0.0
var dy=0.0
var last_wheel_ms=0.0

func keyboard(horizontal:float,vertical:float,dt:float)->void:
 # Original action-set aliases are combined before applying pE; no mouse sensitivity/invert.
 dx+=horizontal*2.1*dt
 dy+=vertical*2.1*.6*dt

func motion(x:float,y:float,sensitivity:float,invert_y:bool)->bool:
 if absf(x)>400.0 or absf(y)>400.0:return false
 dx+=x*.0021*sensitivity
 dy+=y*.0021*sensitivity*(-1.0 if invert_y else 1.0)
 return true

func consume()->Dictionary:
 var result={"dx":dx,"dy":dy}
 clear()
 return result

func clear()->void:
 dx=0.0;dy=0.0

func wheel(now_ms:float,notches:float)->bool:
 if now_ms-last_wheel_ms<280.0 or absf(notches)<1.0:return false
 last_wheel_ms=now_ms
 return true
