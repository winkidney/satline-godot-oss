extends SceneTree
class CollisionStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func raycast(origin:Vector3,direction:Vector3,limit:float=500)->Dictionary:
  if direction.z>=0:return {}
  var distance=(-6-origin.z)/direction.z
  if distance<0 or distance>limit:return {}
  return {"dist":distance,"point":origin+direction*distance,"normal":Vector3.BACK,"surface":"metal"}
class PlayerStub extends RefCounted:
 var pos=Vector3(0,0,-4)
 var crouching=false
 var alive=true
 var health=100.0
 var hits=0
 func damage(amount:float,_position:Vector3)->void:
  hits+=1;health=maxf(0,health-amount)
  if health<=0:alive=false
var events=[]
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is Dictionary:
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0002
 return a==b
func vector(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func matrix(transform:Transform3D)->Array:
 var b=transform.basis;var p=transform.origin
 return [b.x.x,b.x.y,b.x.z,0,b.y.x,b.y.y,b.y.z,0,b.z.x,b.z.y,b.z.z,0,p.x,p.y,p.z,1]
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/bolts-reference.json"))
 var player=PlayerStub.new();var bolts=SaltlineBolts.new(data.modules.enemies.TUNE,CollisionStub.new(),player)
 bolts.impact.connect(func(hit):events.append(hit))
 var failures=[]
 for frame in reference.frames.size():
  var sample:Dictionary=reference.frames[frame];player.pos.z=sample.playerZ;player.crouching=sample.crouching
  if frame==160:player.alive=true;player.health=100
  for shot in sample.spawns:bolts.fire(vector(shot.position),vector(shot.direction))
  bolts.update(.05 if frame%19==0 else 1.0/60)
  var matrices=[]
  for transform in bolts.transforms:matrices.append(matrix(transform))
  var row={"slots":bolts.slots,"matrices":matrices,"hits":player.hits,"emitted":bolts.emitted,"dropped":bolts.dropped,"health":player.health,"alive":player.alive,"impacts":events.size()}
  for key in row:
   if not same(row[key],sample[key]):failures.append("%d %s"%[frame,key])
 if not same(events,reference.events):failures.append("impact events")
 var report={"failures":failures,"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"emitted":bolts.emitted,"dropped":bolts.dropped,"hits":player.hits,"world_hits":bolts.world_hits,"expired":bolts.expired,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/bolts-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,12),"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"expired":bolts.expired,"hits":player.hits}));quit(0 if failures.is_empty() else 1)
