extends SceneTree
class Probe:
 extends SaltlineImpactEffects
 func shade_at(_p:Vector3,_n:Vector3)->float:return 1
func _initialize()->void:
 var fx=Probe.new();fx.tracer_pool=SaltlineTracers.new();fx.lit_pool=SaltlineParticles.new(32,true,fx.rng)
 var failures=[];var checks=0
 fx.tracer(Vector3.ZERO,Vector3(0,0,-4),{"color":"#ff8000","trail":false})
 var expected=fx.fx_color.cached.duplicate()
 fx.smoke(Vector3.ZERO,{"count":1,"color":"invalid"})
 for k in 3:
  checks+=1
  if absf(fx.lit_pool.particles[0].color[k]-expected[k])>1e-7:failures.append("tracer to smoke cache")
 fx.smoke(Vector3.ZERO,{"count":1,"color":"blue"})
 fx.tracer(Vector3.ZERO,Vector3(0,0,-4),{"color":"invalid","trail":false})
 checks+=1
 if fx.tracer_pool.shots[1].color!=Vector3(0,0,16):failures.append("smoke to tracer cache")
 fx.tracer(Vector3.ZERO,Vector3(0,0,-4),{"trail":false})
 checks+=1
 if fx.tracer_pool.shots[2].color.distance_to(Vector3(16,12.8,7.36))>1e-6:failures.append("default fallback")
 checks+=1
 if fx.fx_color.cached!=PackedFloat64Array([0,0,1]):failures.append("default changed cache")
 var report={"checks":checks,"failures":failures,"scope":"Production tracer/smoke share original ph cache; parser itself checked against original 179 case reference."}
 FileAccess.open("res://evidence/fx-shared-color-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));fx.tracer_pool.free();fx.free();quit(0 if failures.is_empty() else 1)
