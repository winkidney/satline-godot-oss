extends SceneTree
class Fx extends SaltlineImpactEffects:
 var requests=[]
 func sparks(p:Vector3,n:Vector3=Vector3.UP,count:int=12)->void:
  requests.append("sparks");super.sparks(p,n,count)
 func smoke(p:Vector3,options:Dictionary={})->void:
  requests.append("smoke");super.smoke(p,options)
class Lights extends SaltlineLightPool:
 var requests=[]
 func flash(p:Vector3,color:int=0xffc880,energy:float=30,radius:float=10,duration:float=.06)->void:
  requests.append("light");super.flash(p,color,energy,radius,duration)
var failures=[]
var checks=0
var maximum=0.0
func _initialize()->void:call_deferred("verify")
func verify()->void:
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/explosive-stream-reference.json"))
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source()
 var physics=SaltlinePhysics.new(scene.source.physics);var player=SaltlinePlayer.new(scene.source.modules.player,physics)
 var fx=Fx.new();root.add_child(fx);fx.setup(scene,scene.camera,physics)
 var lights=Lights.new();root.add_child(lights);lights.requests=fx.requests
 var decals=SaltlineDecals.new(scene);var effects=SaltlineExplosionEffects.new(fx,decals,lights)
 var system=SaltlineExplosives.new(scene,physics,effects,player);var steps=0;var leak_checks=0
 for row in ref.rows:
  var input=row.input;fx.requests.clear();var fx_before=fx.rng.calls;var random_before=system.rng.state
  match input.action:
   "reset":system.reset()
   "chain":system._chain(Vector3(input.position[0],input.position[1],input.position[2]),input.size)
   "leak":
    system.items[int(input.index)].fuse=1.6;system.items[int(input.index)].tick=0;system.update(0)
    checks+=2;leak_checks+=1
    if system.rng.state!=random_before:failures.append("leak advanced explosives stream")
    if fx.rng.calls==fx_before:failures.append("leak did not consume FX stream")
  for j in system.items.size():
   for field in ["fuse","tick"]:
    var expected=row.expected.fuses[j] if field=="fuse" else row.expected.ticks[j]
    var actual=system.items[j][field];var error=absf(actual-expected);maximum=maxf(maximum,error);checks+=1
    if (not is_finite(actual) or error>2e-6) and failures.size()<20:failures.append({"step":steps,"item":j,"field":field,"error":error})
  checks+=3
  if system.rng.state!=int(row.expected.rng_state) or system.rng.calls!=int(row.expected.rng_calls):failures.append("RNG mismatch "+str(steps))
  if fx.requests!=row.expected.requests:failures.append("requests mismatch "+str(steps))
  steps+=1
 var report={"steps":steps,"checks":checks,"leak_checks":leak_checks,"maximum_error":maximum,"vector_tolerance":2e-6,"rng_comparison":"exact state/count","failures":failures,"source_sha256":ref.source_sha256,"methods_sha256":ref.methods_sha256,"scope":ref.scope+" Actual Native explosives and actual FX sparks/smoke receivers; FX request order and separate random consumption checked, not FX particle numeric output."}
 FileAccess.open("res://evidence/explosive-stream-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));scene.queue_free();fx.queue_free();lights.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
