extends SceneTree

var failures=[]
var checks=0

func check(condition:bool,label:String)->void:
 checks+=1
 if not condition:failures.append(label)

func _initialize()->void:call_deferred("run")

func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 await process_frame;RenderingServer.force_draw(false)
 var scan=game.enemy_manager.scan_light;var pool=game.light_pool
 scan.update(1.0/60,[],Vector3.ZERO)
 var slot=scan.slot
 check(not slot.is_empty(),"scan acquired a slot")
 if slot.is_empty():game.queue_free();quit(1);return
 var index=pool.slots.find(slot);var light=slot.light
 for cycle in 8:
  var owned=[]
  for i in 5:
   owned.append(game.explosion_effects.add_emitter(Vector3(i,1,0),"fire",{"ttl":10,"scale":1}))
  check(owned.all(func(emitter):return emitter.light!=null),"fire acquired remaining slots %d"%cycle)
  var emitted=pool.emitted;pool.flash(Vector3.ZERO)
  check(pool.emitted==emitted,"full persistent pool rejects flash %d"%cycle)
  game._reset_session("standard",cycle>0)
  check(scan.slot==slot and pool.slots.find(scan.slot)==index and scan.slot.light==light,"retry retains scan identity %d"%cycle)
  check(slot.busy and slot.persistent and slot.source_intensity==0,"retry retains dark scan reservation %d"%cycle)
  check(game.explosion_effects.emitters.is_empty(),"retry stops fire emitters %d"%cycle)
  for emitter in owned:check(emitter.light==null,"retry releases fire light %d"%cycle)
  pool.set_energy(slot,17)
  for i in 20:pool.flash(Vector3(i,2,0),0xff0000,10+i,8,.1+i*.001)
  pool.update(1)
  check(slot.busy and slot.persistent and slot.source_intensity==17,"flash saturation preserves scan %d"%cycle)
  var busy=0
  for item in pool.slots:
   if item.busy:busy+=1
  check(busy==1,"all temporary lights expire %d"%cycle)
 scan.dispose()
 check(not slot.busy and not slot.persistent and slot.source_intensity==0,"dispose releases scan")
 var report={"checks":checks,"failures":failures,"cycles":8,"capacity":pool.slots.size(),"scope":"Actual Main session reset, five simultaneous fire reservations, saturated flashes, expiry, retained scan slot identity and disposal; no claim of whole-frame visual equivalence."}
 var file=FileAccess.open("res://evidence/session-light-lifecycle-verification.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report))
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
