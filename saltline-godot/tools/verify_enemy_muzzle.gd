extends SceneTree
class LightStub extends SaltlineLightPool:
 var flashes=[]
 func flash(position:Vector3,color:int=0xffc880,energy:float=30,radius:float=10,duration:float=.06)->void:flashes.append({"position":position,"color":color,"energy":energy,"radius":radius,"duration":duration})
var maximum=0.0
var comparisons=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Array:
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if a is Dictionary:
  for key in b:
   if not same(a[key],b[key]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.00001
 return a==b
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/enemy-muzzle-reference.json"))
 var fx=SaltlineImpactEffects.new();fx.pool=SaltlineParticles.new(100);fx.lit_pool=SaltlineParticles.new(100);var lights=LightStub.new();fx.light_pool=lights
 var failures=[]
 for sample in reference.cases:
  fx.pool.clear();fx.lit_pool.clear();lights.flashes.clear();fx.enemy_muzzle_flash(Vector3(2,3,4),Vector3.RIGHT,sample.scale)
  if fx.pool.particles.size()!=8 or fx.lit_pool.particles.size()!=1:failures.append("counts %s"%sample.scale);continue
  for i in 4:
   var p:Dictionary=fx.pool.particles[i];var expected:Array=sample.layers[i]
   var actual=[p.position.x,p.position.y,p.position.z,p.life,p.s0,p.s1,p.color.x,p.color.y,p.color.z,p.frame]
   if not same(actual,expected):failures.append("layer %s %d"%[sample.scale,i])
  var axial:Dictionary=fx.pool.particles[4];var expected:Array=sample.axial[0]
  if not same([axial.position.x,axial.position.y,axial.position.z,axial.velocity.x,axial.velocity.y,axial.velocity.z,axial.life,axial.s0,axial.s1],expected):failures.append("axial %s"%sample.scale)
  if not same({"mode":axial.mode,"frame":axial.frame,"stretch":axial.stretch,"color":axial.color,"fadeOut":axial.fade_out},sample.axialFields):failures.append("axial fields %s"%sample.scale)
  for i in range(5,8):
   var p:Dictionary=fx.pool.particles[i]
   if p.life<.08 or p.life>.22 or p.velocity.length()<8 or p.velocity.length()>22 or not same([p.s0,p.s1,p.mode,p.frame,p.color.x,p.color.y,p.color.z],[.012,.006,1,1,18,10.8,4.2]):failures.append("spark %s %d"%[sample.scale,i])
  var smoke:Dictionary=fx.lit_pool.particles[0];var expected_smoke:Array=sample.lit[0]
  var actual=[smoke.position.x,smoke.position.y,smoke.position.z,smoke.velocity.x,smoke.velocity.y,smoke.velocity.z,smoke.s0,smoke.s1,smoke.color.x,smoke.color.y,smoke.color.z,smoke.alpha,smoke.shade,smoke.drag,-smoke.gravity,smoke.wind]
  var wanted=expected_smoke.slice(0,6)+expected_smoke.slice(7,17)
  if not same(actual,wanted) or smoke.life<.5 or smoke.life>.9:failures.append("smoke %s"%sample.scale)
  if not same(lights.flashes,sample.lights):failures.append("lights %s"%sample.scale)
 var report={"failures":failures,"cases":reference.cases.size(),"comparisons":comparisons,"maximum_error":maximum,"scope":reference.scope}
 fx.free();lights.free()
 var file=FileAccess.open("res://evidence/enemy-muzzle-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
