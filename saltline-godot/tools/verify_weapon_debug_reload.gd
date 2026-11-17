extends SceneTree
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var w=SaltlineWeapon.new(data.modules.weapon)
 var initial_ammo=w.slots.rifle.ammo
 var events=[]
 w.phase_event.connect(func(kind,gun,phase):events.append([kind,gun,phase]))
 w.debug_reload_time=3.0
 var player={"alive":true,"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
 var input={"fire":false,"ads":false}
 for i in 12:w.update(1.0/60,input,player)
 var debug_start=events.has(["reload","rifle","start"])
 var full_ammo=w.slots.rifle.ammo==initial_ammo
 var held=not w.reload.is_empty() and w.reload.t==3.0
 w.debug_reload_time=null;w.update(1.0/60,input,player)
 var report={"full_ammo_preserved":full_ammo,"debug_start_emitted":debug_start,"fixed_time_beyond_duration_held":held,"normal_completion_restored":w.reload.is_empty()}
 print(JSON.stringify(report));FileAccess.open("res://evidence/weapon-debug-reload.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));quit(0 if held and w.reload.is_empty() and full_ammo and not debug_start else 1)
