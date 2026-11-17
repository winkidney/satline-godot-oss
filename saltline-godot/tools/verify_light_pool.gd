extends SceneTree
func _initialize()->void:
 call_deferred("_verify")
func _verify()->void:
 var pool=load("res://scripts/light_pool.gd").new();root.add_child(pool)
 var failures=[]
 if pool.slots.size()!=6:failures.append("six shared slots")
 pool.flash(Vector3.ZERO,0xffffff,100,10,1)
 pool.update(.25)
 if absf(pool.slots[0].source_intensity-75)>.001 or absf(pool.slots[0].light.light_energy-75/PI)>.001:failures.append("linear fade")
 var persistent=pool.acquire();pool.set_energy(persistent,42)
 for i in 8:pool.flash(Vector3(i,0,0),0xff0000,10+i,8,.2+i*.01)
 if pool.slots[0].peak!=100:failures.append("long-lived temporary slot must be retained")
 for i in range(2,6):
  if pool.slots[i].peak!=12+i:failures.append("replace smallest ttl first")
 if not persistent.persistent or persistent.source_intensity!=42 or absf(persistent.light.light_energy-42/PI)>.00001:failures.append("persistent slot cannot be stolen")
 pool.update(1)
 var active=0
 for slot in pool.slots:
  if slot.busy:active+=1
 if active!=1:failures.append("temporary lights expire")
 pool.release(persistent)
 var acquired=[]
 for i in 6:acquired.append(pool.acquire())
 if not pool.acquire().is_empty():failures.append("persistent pool capacity")
 var before=pool.emitted;pool.flash(Vector3.ZERO)
 if pool.emitted!=before:failures.append("flash must not replace persistent lights")
 for slot in acquired:pool.release(slot)
 var report={"failures":failures,"capacity":pool.slots.size(),"checks":["source linear flash fade plusnative /PI","oldest temporary replacement","persistent acquisition protection","expiry and release","capacity exhaustion"]}
 var file=FileAccess.open("res://evidence/light-pool-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));pool.queue_free();quit(0 if failures.is_empty() else 1)
