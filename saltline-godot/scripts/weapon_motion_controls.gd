extends RefCounted
# Original O targets/idle inspection/finger controls, 79625 and 79730–79772.
const Math=preload("res://scripts/weapon_motion_math.gd")
var a:Dictionary
func _init(state:Dictionary)->void:a=state
static func damp(value:float,target:float,rate:float,dt:float)->float:
 return target+(value-target)*exp(-rate*dt)
func targets(sprint:bool,fire:bool,ads:bool,reloading:bool)->void:
 a.spWant=sprint;a.urgent=not sprint and (fire or ads or reloading)
func finish(dt:float,definition:Dictionary,input:Dictionary,speed:float,switching:bool,fire:bool,can_fire:bool,debug_flash:bool=false)->Array:
 var look:Dictionary=input.look if input.get("look") is Dictionary else {}
 var look_active=absf(float(look.get("dx",0)))+absf(float(look.get("dy",0)))>.002
 if fire or input.get("ads",false) or a.reload!=null or switching or speed>.2 or look_active or a.sprintT>.1:
  a.idleT=0
  if a.inspect>=0:a.inspect=maxf(a.inspect,2.9)
 else:a.idleT+=dt
 if definition.get("inspect",false) and a.inspect<0 and a.idleT>24:a.inspect=0
 var result=[0.0,0.0,0.0]
 if a.inspect>=0:
  a.inspect+=dt
  var time=float(a.inspect)
  result[0]=Math.ease(time/.5)*(1.0-Math.ease((time-1.4)/.5))
  result[1]=Math.ease((time-1.5)/.5)*(1.0-Math.ease((time-2.8)/.5))
  result[2]=Math.ease(time/.5)*(1.0-Math.ease((time-2.9)/.5))
  if time>3.5:a.inspect=-1;a.idleT=0
 a.finger=damp(a.finger,1.0 if (fire and can_fire) or debug_flash else 0.0,30,dt)
 return result
func dry()->void:a.bump.v-=.08
