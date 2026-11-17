extends RefCounted
# Actual Main effect adapter; geometry/camera setup is owned by showcase scene.
var game
var timeline
var targets
func _init(main,mode:String="all",params:Dictionary={})->void:
 game=main
 var rng=game.impact_effects.rng
 targets=preload("res://scripts/fx_showcase_impact.gd").new(rng,game.player.physics.raycast,_effect)
 timeline=preload("res://scripts/fx_showcase_timeline.gd").new(mode,rng,_action,params)
 if mode in ["all","impact"]:
  game.explosion_effects.add_emitter(Vector3(-6.2,.05,-1.5),"steam")
  game.explosion_effects.add_emitter(Vector3(5.6,0,1.6),"fire")
  game.explosion_effects.add_emitter(Vector3(.4,2.6,1.6),"drip")
func update(dt:float)->void:timeline.update(dt)
func _action(kind:String,values:Dictionary)->void:
 if kind=="impact":targets.trigger(int(values.index))
 else:_effect(kind,values)
func _effect(kind:String,values:Dictionary)->void:
 match kind:
  "tracer":game.impact_effects.tracer(values.position,values.target,values.options)
  "muzzle":game.impact_effects.muzzle_flash(values.position,values.direction,values.options)
  "shell":game.shells.emit(values.position,values.velocity)
  "explosion":game.explosion_effects.explode(values.position,values.size)
  "impact":game._impact_visuals(values,values.dir)
