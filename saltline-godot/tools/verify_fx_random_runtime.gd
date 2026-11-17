extends "res://tools/verify_source_bootstrap_runtime.gd"
var fx_checks=0
func _process(dt:float)->bool:
 if game!=null and not finishing and frame==0:
  for stream in [game.impact_effects.rng,game.impact_effects.pool.rng,game.impact_effects.lit_pool.rng,game.impact_effects.debris.rng,game.shells.rng,game.decals.rng,game.explosion_effects.rng,game.sky_weather.rng,game.tracers.rng,game.impact_effects.batch.rng,game.impact_effects.lit_batch.rng]:
   fx_checks+=1
   if stream!=game.fx_random:fail("FX consumer did not share Math.random namespace")
 return super._process(dt)
func finish()->void:
 if game.fx_random.calls<=0:fail("actual runtime did not draw shared FX random")
 var report={"frames":frame,"fx_identity_checks":fx_checks,"fx_calls":game.fx_random.calls,"failures":failures,"scope":"Actual Main one FX Math.random service across impact/additive/lit/debris/shell/decal/explosion/sky consumers; existing470-frame arms/mechanical/magazine path. Ownership proof, not full original FX draw schedule or entropy equivalence."}
 FileAccess.open("res://evidence/fx-random-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));await super.finish()
