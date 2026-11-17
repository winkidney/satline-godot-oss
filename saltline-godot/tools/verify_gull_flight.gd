extends SceneTree
class CollisionStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func ground_height(_x:float,_z:float,_y:float=0)->float:return 0
 func raycast(origin:Vector3,direction:Vector3,limit:float=500)->Dictionary:
  var hit={}
  for face in [[0,12,Vector3.LEFT],[0,-12,Vector3.RIGHT],[1,0,Vector3.UP],[1,9,Vector3.DOWN],[2,12,Vector3.FORWARD],[2,-12,Vector3.BACK]]:
   var axis=int(face[0]);var component=float(direction[axis])
   if absf(component)<1e-9:continue
   var distance=(face[1]-origin[axis])/component
   if distance<0 or distance>limit or (not hit.is_empty() and distance>=hit.dist):continue
   hit={"dist":distance,"normal":face[2]}
  return hit
class ManagerStub extends SaltlineEnemyCoordinator:
 func think(_state:Dictionary,_dt:float,_delay:float)->void:pass
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Array:
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.001
 return a==b
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/gull-flight-reference.json"))
 var state:Dictionary=reference.input.duplicate(true);var manager=ManagerStub.new(data.modules.enemies.TUNE,CollisionStub.new(),{"pos":Vector3(-4,0,6)})
 var flight=SaltlineGullFlight.new(state,manager);var failures=[]
 for frame in reference.frames.size():
  if frame==240:state.mode="investigate"
  if frame==480:state.mode="engage";state.noSeeT=0
  if frame==600:state.hp=20
  if frame==720:state.atk="tele"
  if frame==840:state.noSeeT=2
  if frame==960:state.mode="patrol";state.hoverFixed=true;state.alt=1.6
  if frame==1080:state.mode="search";state.hoverFixed=false
  manager.time=float(frame+1)/60;flight.update(1.0/60)
  var row={"heading":flight.heading_error,"horizontal":flight.horizontal_speed,"acceleration":flight.acceleration,"bodyY":flight.body_y,"rotors":flight.rotor_angles}
  for key in reference.frames[frame]:
   var actual=row[key] if row.has(key) else state[key]
   if not same(actual,reference.frames[frame][key]):failures.append("%d %s"%[frame,key])
 if absf(manager.rng.randf()-reference.nextRandom)>1e-12:failures.append("random consumption")
 var report={"failures":failures,"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/gull-flight-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,8),"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum}));quit(0 if failures.is_empty() else 1)
