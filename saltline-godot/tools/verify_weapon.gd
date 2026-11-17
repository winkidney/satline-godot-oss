extends SceneTree
var errors=[]
var events=[]
func check(condition:bool,message:String)->void:
 if not condition:errors.append(message)
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
 var player={"sprinting":false,"speed":0.0,"on_ground":true,"crouching":false}
 var input={"fire":true,"ads":false}
 weapon.phase_event.connect(func(event,gun,phase):events.append([event,gun,phase]))
 for i in 120:weapon.update(1.0/60,input,player)
 check(weapon.shot_count==24,"720 RPM must produce 24 shots in two seconds")
 check(weapon.slots.rifle.ammo==6,"rifle ammunition consumption")
 input.fire=false
 check(weapon.reload_now(),"tactical reload starts")
 for i in 86:weapon.update(1.0/60,input,player)
 check(weapon.slots.rifle.ammo==6,"ammo must wait for magin at 1.44s")
 weapon.update(1.0/60,input,player);weapon.update(1.0/60,input,player)
 check(weapon.slots.rifle.ammo==30 and weapon.slots.rifle.reserve==126,"magin transfers exact rounds")
 weapon.switch_to("pistol")
 for i in 40:weapon.update(1.0/60,input,player)
 check(weapon.current=="pistol" and weapon.switching.is_empty(),"switch completes after holster and draw")
 var before=weapon.shot_count
 input.fire=true
 for i in 60:weapon.update(1.0/60,input,player)
 check(weapon.shot_count-before==1,"pistol must not auto-fire while trigger held")
 for i in 14:
  input.fire=false
  for frame in 10:weapon.update(1.0/60,input,player)
  input.fire=true;weapon.update(1.0/60,input,player)
 check(weapon.slots.pistol.ammo==0,"pistol has fifteen rounds")
 input.fire=false;weapon.reload_now()
 for i in 120:weapon.update(1.0/60,input,player)
 check(weapon.slots.pistol.ammo==15 and is_inf(weapon.slots.pistol.reserve),"pistol infinite reserve survives reload")
 check(events.has(["reload","pistol","slide"]),"empty pistol reload releases slide")
 weapon.slots.pistol.ammo=5;weapon.reload_now()
 for i in 20:weapon.update(1.0/60,input,player)
 weapon.switch_to("rifle")
 check(weapon.reload.is_empty() and weapon.slots.pistol.ammo==5,"switch interrupts reload before magin without granting ammo")
 var report={"failures":errors,"shots":weapon.shot_count,"events":events,"checks":10}
 var file=FileAccess.open("res://evidence/weapon-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify(report));quit(0 if errors.is_empty() else 1)
