extends RefCounted
# Original KP/C scheduling. Dispatch synchronously: effect callbacks consume the
# same random stream before the following showcase action is constructed.
var mode="all"
var hold=""
var fixed_size=0.0
var rng
var dispatch:Callable
var impact_index=0
var explosion_index=0
var impact_timer=0.0
var tracer_timer=.2
var shell_timer=0.0
var explosion_timer=3.4
var clock=0.0
func _init(kind:String="all",random_stream=null,callback:Callable=Callable(),params:Dictionary={})->void:
 mode=kind;rng=random_stream if random_stream!=null else preload("res://scripts/fx_random.gd").new();dispatch=callback
 hold=str(params.get("fxhold",""));fixed_size=float(params.get("fxsize",0))
 if mode=="explosion":explosion_timer=.6
func _send(kind:String,values:Dictionary)->void:
 if dispatch.is_valid():dispatch.call(kind,values)
func update(dt:float)->void:
 clock+=dt
 if hold=="muzzle":
  _send("muzzle",{"position":Vector3(0,1.3,3),"direction":Vector3.RIGHT,"options":{"scale":1}})
  _send("muzzle",{"position":Vector3(2.5,1.3,3),"direction":Vector3(-.5,0,.86),"options":{"scale":1.6}})
 if mode in ["all","impact"]:
  impact_timer-=dt
  while impact_timer<=0:
   impact_timer+=.09 if mode=="impact" else .13
   _send("impact",{"index":impact_index%8});impact_index+=1
 if mode in ["all","tracer"]:
  tracer_timer-=dt
  if tracer_timer<=0:
   tracer_timer+=.16 if mode=="tracer" else .45
   var target=Vector3(-5+rng.randf()*3,1.2+rng.randf()*.8,6+rng.randf()*2)
   var origin=Vector3(5.2,1.3,3.2)
   _send("muzzle",{"position":origin,"direction":(target-origin).normalized(),"options":{"scale":1}})
   _send("tracer",{"position":origin,"target":target,"options":{"color":16730658,"speed":120}})
   if mode=="tracer":
    target=Vector3(6,1+rng.randf()*1.5,-6-rng.randf()*6)
    _send("tracer",{"position":Vector3(-7,1.6,6.5),"target":target,"options":{"speed":200}})
  shell_timer-=dt
  if shell_timer<=0:
   shell_timer+=.22
   var velocity=Vector3(1.6+rng.randf()*.8,1.6+rng.randf()*.8,.4+(rng.randf()-.5)*.8)
   _send("shell",{"position":Vector3(-4.6,1.35,4.2),"velocity":velocity})
 if mode in ["all","explosion"]:
  explosion_timer-=dt
  if explosion_timer<=0:
   explosion_timer+=2.4 if mode=="explosion" else 3.5
   var size=fixed_size
   if size==0:size=1+explosion_index%3;explosion_index+=1
   _send("explosion",{"position":Vector3(0,.25,3.5) if mode=="explosion" else Vector3(7,.25,-3.5),"size":size})
