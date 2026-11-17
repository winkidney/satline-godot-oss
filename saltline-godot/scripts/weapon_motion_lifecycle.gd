extends RefCounted
# State-only original equip (_), reset (T), snap; node/arms side effects are external.
const Math=preload("res://scripts/weapon_motion_math.gd")
const RECOIL=["kZ","kP","kY","kR","kX","kU"]
const DYNAMIC=["kZ","kP","kY","kR","kX","kU","swY","swP","jY","jP","jR","inZ","inX","inP","inR","bump","antY","antR","amt","wall"]
var a:Dictionary
var rigs:Dictionary
func _init(state:Dictionary,source_rigs:Dictionary)->void:a=state;rigs=source_rigs
func equip(gun:String)->void:
 var motion:Dictionary=rigs[gun].motion
 for key in RECOIL:
  a[key].w=motion.recoil.spr[key][0];a[key].z=motion.recoil.spr[key][1];Math.reset(a[key])
 for group in [[ ["swY","swP"],motion.sway.spr ],[ ["jY","jP","jR"],motion.air.spr ],[ ["inZ","inX","inP","inR"],motion.inertia.spr ]]:
  for key in group[0]:a[key].w=group[1][0];a[key].z=group[1][1]
 for key in ["adsV","adsS","rwS","rkS","antY","antR"]:Math.reset(a[key])
 a.merge({"antYT":0,"antRT":0,"adsWant":false,"reloadW":0,"rackW":0,"cooldown":0,"fireQ":0,"dryDone":false,"burst":0,"bloom":0,"heat":0,"smoke":0,"flashT":0,"finger":0,"adsLin":0,"adsE":0,"inspect":-1,"idleT":0,"autoReload":-1},true)
func reset()->void:
 a.reload=null
 a.merge({"prevFire":false,"lastShot":-9,"sprintT":0,"reloadW":0,"rackW":0,"hol":0,"gait":0,"gOffT":0,"spd":0,"stepEv":0,"jumpEv":0,"landEv":-1,"lpR":0,"lpF":0,"exert":0,"wallK":0,"wasGround":true},true)
 for key in DYNAMIC:Math.reset(a[key])
 for key in ["spV","stance","stance2","gOff"]:Math.reset(a[key])
 Math.reset(a.stride,1.55);equip("rifle")
func snap(player:Dictionary,input:Dictionary,switching:bool=false,debug_ads:bool=false,debug_sprint:bool=false)->void:
 var sprint=(bool(player.get("sprinting",false)) or debug_sprint) and not input.get("fire",false) and not input.get("ads",false) and a.reload==null
 a.adsLin=1.0 if (input.get("ads",false) or debug_ads) and not switching else 0.0
 a.adsE=Math.ease(a.adsLin);a.adsWant=a.adsLin>0;a.sprintT=1.0 if sprint else 0.0;a.spWant=sprint
 for key in DYNAMIC:Math.reset(a[key])
 Math.reset(a.adsV,a.adsLin);Math.reset(a.adsS,a.adsLin);Math.reset(a.spV,a.sprintT);Math.reset(a.rwS,a.reloadW);Math.reset(a.rkS,a.rackW)
 a.lpR=0;a.lpF=0;a.gait+=a.gOff.x;Math.reset(a.gOff);a.gOffT=0;a.stepEv=0;a.jumpEv=0;a.landEv=-1
 var ground=player.get("onGround",true);a.wasGround=not (ground is bool and ground==false)
 var stance=1.0 if player.get("crouching",false) else 0.0
 Math.reset(a.stance,stance);Math.reset(a.stance2,stance);a.wallK=0;a.antYT=0;a.antRT=0
