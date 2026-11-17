extends SceneTree
class CollisionStub extends SaltlinePhysics:
 func _init()->void:super({"boxes":[],"bounds":{}})
 func raycast(origin:Vector3,direction:Vector3,limit:float=500)->Dictionary:
  if direction.y>=0:return {}
  var distance=-origin.y/direction.y
  if distance<0 or distance>limit:return {}
  return {"point":origin+direction*distance,"normal":Vector3.UP,"dist":distance}
class ManagerStub extends SaltlineEnemyCoordinator:
 func provoke(_state:Dictionary)->void:pass
var killed=0
var retired=0
var lens=Vector3.ZERO
var scales=[1,1,1,1]
var effects=[]
var explosions=[]
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Dictionary:
  for key in b:
   if not a.has(key) or not same(a[key],b[key]):return false
  return true
 if a is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0001
 return a==b
func snapshot(state:Dictionary,flight:SaltlineGullFlight)->Dictionary:
 var row=state.duplicate(true);row.merge({"killed":killed,"retired":retired,"rotors":flight.rotor_angles,"rotorScales":scales,"lens":lens},true);return row
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/gull-life-reference.json"))
 var state:Dictionary=reference.input.duplicate(true);var manager=ManagerStub.new(data.modules.enemies.TUNE,CollisionStub.new(),null)
 var flight=SaltlineGullFlight.new(state,manager);var life=SaltlineGullLife.new(flight)
 life.killed.connect(func():killed+=1;lens=Vector3(.3,.05,.02))
 life.retired.connect(func():retired+=1;state.active=false)
 life.rotor_lost.connect(func(index):scales[index]=.0001)
 life.effect_requested.connect(func(kind,position,options):effects.append({"kind":kind,"position":position,"options":options}))
 life.explosion_requested.connect(func(position,radius,damage):explosions.append({"position":position,"radius":radius,"damage":damage,"source":"enemy"}))
 var failures=[]
 for i in reference.damageCases.size():
  var sample:Dictionary=reference.damageCases[i];var direction=Vector3(sample.direction[0],sample.direction[1],sample.direction[2])
  if life.damage(sample.amount,state.pos,direction,"body")!=reference.damageResults[i]:failures.append("damage %d"%i)
 if not same(snapshot(state,flight),reference.death):failures.append("death")
 for frame in reference.frames.size():
  life.update(1.0/60)
  if not same(snapshot(state,flight),reference.frames[frame]):failures.append("frame %d"%frame)
 if not same(effects,reference.effects):failures.append("effects")
 if not same(explosions,reference.explosions):failures.append("explosion")
 if absf(manager.rng.randf()-reference.nextRandom)>1e-12:failures.append("random consumption")
 var report={"failures":failures,"frames":reference.frames.size(),"comparisons":comparisons,"maximum_error":maximum,"effects":effects.size(),"killed":killed,"retired":retired,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/gull-life-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
