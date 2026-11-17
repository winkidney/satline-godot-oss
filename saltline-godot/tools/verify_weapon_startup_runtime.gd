extends "res://tools/verify_weapon_arms_runtime.gd"
var startup_checks=0
func _process(dt:float)->bool:
 if game!=null and not finishing and frame==0:
  startup_checks+=3
  if game.weapon.startup_info.mode!="canonical":fail("Main did not use canonical initial state")
  if game.weapon.startup_info.weapon_seed!=3554171070:fail("Main weapon fork seed mismatch")
  if game.weapon.time!=0:fail("Main started from sampled clock")
 return super._process(dt)
func finish()->void:
 var report={"startup":game.weapon.startup_info,"startup_checks":startup_checks,"frames":frame,"failures":failures,"scope":"Actual Main default startup plus existing470-frame normal arms/mechanical/magazine GPU path. Kernel and browser cold-bootstrap proof separate; no global FX/AI RNG equivalence."}
 FileAccess.open("res://evidence/weapon-startup-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 await super.finish()
