extends SceneTree
var failures=[]
var checks=0
func compare(a,b,path:String)->void:
 if b is Dictionary:
  for k in b:compare(a[k],b[k],path+"/"+k)
 elif b is bool or b==null:
  checks+=1
  if a!=b:failures.append(path)
 else:
  checks+=1
  if not is_finite(float(a)) or absf(float(a)-float(b))>1e-12:failures.append(path)
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var ref=preload("res://scripts/weapon_startup.gd").load_reference()
 var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
 compare(weapon.motion_state,ref.state,"S")
 compare(weapon.time,0,"time");compare(weapon.motion_rng.seed,ref.weapon_seed,"seed")
 for j in ref.sequence.size():compare(weapon.motion_randf(),ref.sequence[j],"rng/"+str(j))
 checks+=1
 if weapon.startup_info.seed_mode!="canonical_fork":failures.append("default seed mode")
 var override=load("res://scripts/weapon.gd").new(data.modules.weapon,{},1234)
 checks+=1
 if override.startup_info.mode!="canonical" or override.startup_info.seed_mode!="explicit_seed":failures.append("state/seed provenance not independent")
 var old_state=weapon.motion_rng.state;weapon.reset();compare(weapon.motion_rng.state,old_state,"reset RNG history")
 var explicit=load("res://scripts/weapon.gd").new(data.modules.weapon,data.modules.weapon.debug.S,4207)
 compare(explicit.time,data.modules.weapon.debug.S.t,"explicit snapshot time");compare(explicit.motion_rng.seed,4207,"explicit seed")
 var report={"checks":checks,"failures":failures,"startup":weapon.startup_info,"forks":ref.forks,"source_sha256":ref.source_sha256,"initial_state_sha256":ref.initial_state_sha256,"scope":ref.scope+" Actual default Weapon constructor, first64 RNG samples, reset preserves RNG, explicit snapshot/seed injection."}
 FileAccess.open("res://evidence/weapon-startup-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
