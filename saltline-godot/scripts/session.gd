class_name SaltlineSession
extends RefCounted

var mission:SaltlineMission
var player:SaltlinePlayer
var weapon:SaltlineWeapon
var camera:Camera3D
var effects:SaltlineImpactEffects
var explosions:SaltlineExplosionEffects
var explosives:SaltlineExplosives
var shells:SaltlineShells
var tracers:SaltlineTracers
var decals:SaltlineDecals
var weapon_effects:SaltlineWeaponEffects
var animation:SaltlineWeaponAnimation

func reset(mode:String,keep_retries:bool)->void:
 mission.manager.clear();effects.clear();explosions.clear();shells.clear();tracers.clear();decals.clear()
 if animation.drop_view!=null:animation.drop_view.restore(weapon)
 mission.manager.combat.reset_stats();weapon.reset();weapon_effects.clear();explosives.reset();mission.reset_run(mode,keep_retries)
 player.reset(mission.level.playerStart,camera);animation.last_shot=-9;animation.update(weapon)
 if mode!="holdout":mission.spawn_patrol()
