extends SceneTree
func _initialize()->void:
 var fx=load("res://scripts/impact_effects.gd").new()
 fx.physics=SaltlinePhysics.new({"boxes":[],"bounds":{}})
 var failures=[];var cases=[]
 for size in [.4,1.0,2.0]:
  fx.pool=SaltlineParticles.new();fx.lit_pool=SaltlineParticles.new(1400,true)
  fx.splash(Vector3(35,-1.6,0),size)
  var drops=roundi(14*minf(size,1.6))
  if fx.lit_pool.particles.size()!=7 or fx.pool.particles.size()!=drops+2:failures.append("source emission counts size %s"%size)
  for i in drops:
   var p:Dictionary=fx.pool.particles[i]
   if p.flags!=2 or absf(p.floor+1.6)>.0001 or p.frame!=6:failures.append("droplet floor removal configuration")
  if fx.pool.particles[-1].mode!=2 or absf(fx.pool.particles[-1].fade_in-.35)>.0001:failures.append("surface ripple configuration")
  cases.append({"size":size,"lit":fx.lit_pool.particles.size(),"add":fx.pool.particles.size()})
  fx.pool.update(0,Vector3.ZERO,Vector3.ZERO,0);fx.lit_pool.update(0,Vector3.ZERO,Vector3.ZERO,0)
  fx.pool.update(2,Vector3.ZERO,Vector3.ZERO,2);fx.lit_pool.update(2,Vector3.ZERO,Vector3.ZERO,2)
  if not fx.pool.particles.is_empty() or not fx.lit_pool.particles.is_empty():failures.append("splash lifetime")
 var report={"failures":failures,"cases":cases,"source":"Active source k splash function lines 59090-59195; existing particle-core source reference covers motion"}
 var file=FileAccess.open("res://evidence/splash-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));fx.free();quit(0 if failures.is_empty() else 1)
