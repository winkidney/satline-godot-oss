extends RefCounted
# KP/I target selection; synchronous tracer before impact dispatch.
var rng
var raycast:Callable
var dispatch:Callable
var sequence=0
func _init(random_stream,query:Callable,callback:Callable)->void:rng=random_stream;raycast=query;dispatch=callback
func trigger(index:int)->void:
 var origin=Vector3(-6.5,1.5,7) if sequence%2==0 else Vector3(6.5,1.4,7)
 sequence+=1
 var point:Vector3
 if index==5:
  point=Vector3(-1.5+rng.randf()*.3,2.5+rng.randf()*.3,.8)
  var normal=(origin-point).normalized();var direction=(point-origin).normalized()
  dispatch.call("tracer",{"position":origin,"target":point,"options":{}})
  dispatch.call("impact",{"point":point,"normal":normal,"surface":"enemy","dir":direction,"enemy":{},"from":"player"})
  return
 if index==0:point=Vector3(-3.2+(rng.randf()-.5)*2,.4+rng.randf()*1.5,0)
 elif index==1 or index==7:point=Vector3((rng.randf()-.5)*1.8,.3+rng.randf()*1.5,0)
 elif index==2:point=Vector3(3.2+(rng.randf()-.5)*.9,.2+rng.randf()*.9,.6)
 elif index==3:point=Vector3(-1.6+(rng.randf()-.5)*1.2,0,2.2+rng.randf())
 elif index==4:point=Vector3(1.5+(rng.randf()-.5)*.8,0,2.6+rng.randf()*.8)
 else:point=Vector3(3.4+(rng.randf()-.5),0,2.4+rng.randf()*.6)
 var direction=(point-origin).normalized()
 var hit:Dictionary=raycast.call(origin,direction,100)
 if hit.is_empty():return
 dispatch.call("tracer",{"position":origin,"target":hit.point,"options":{}})
 dispatch.call("impact",{"point":hit.point,"normal":hit.normal,"surface":"water" if index==4 else "dirt" if index==6 else hit.surface,"dir":direction,"enemy":null,"from":"player"})
