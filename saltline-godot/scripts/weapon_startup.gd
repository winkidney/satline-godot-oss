extends RefCounted
const Rng=preload("res://scripts/source_rng.gd")
static func load_reference()->Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-startup.json"))
static func state()->Dictionary:return load_reference().state.duplicate(true)
static func weapon_seed(world_seed:int=4207)->int:
 var parent=Rng.new(world_seed)
 # Normal source bootstrap forks: level, rain, explosives, then weapon.
 for j in 3:parent.fork()
 return parent.fork().seed
