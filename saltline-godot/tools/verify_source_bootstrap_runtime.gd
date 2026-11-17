extends "res://tools/verify_weapon_startup_runtime.gd"
var shared_checks=0
func _process(dt:float)->bool:
 if game!=null and not finishing and frame==0:
  shared_checks+=4
  if game.weapon.motion_rng!=game.source_bootstrap.streams.weapon:fail("weapon did not use shared child stream")
  if game.explosives.rng!=game.source_bootstrap.streams.explosives:fail("explosives did not use shared child stream")
  if game.mission.rng!=game.source_bootstrap.root:fail("mission did not use shared global root")
  if game.enemy_coordinator.rng.seed!=9001:fail("AI independent seed changed")
 return super._process(dt)
func finish()->void:
 var report={"shared_checks":shared_checks,"root_seed":game.source_bootstrap.root.seed,"root_calls":game.source_bootstrap.root.calls,"explosive_seed":game.explosives.rng.seed,"explosive_calls":game.explosives.rng.calls,"weapon_seed":game.weapon.motion_rng.seed,"weapon_calls":game.weapon.motion_rng.calls,"frames":frame,"failures":failures,"scope":"Actual Main ownership of post-build shared root/weapon/explosives and independent AI seed;470-frame existing arms/mechanical/magazine path. Does not prove exact full-source stochastic event schedule or Math.random FX."}
 FileAccess.open("res://evidence/source-bootstrap-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await super.finish()
