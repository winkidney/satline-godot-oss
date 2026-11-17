class_name SaltlineWeaponEffects
extends Node3D

var scene:SaltlineSourceScene
var camera:Camera3D
var weapon:SaltlineWeapon
var flashes:Dictionary={}
var light_pool:SaltlineLightPool
var flashes_emitted=0

func setup(source:SaltlineSourceScene,view:Camera3D,state:SaltlineWeapon,shared_lights:SaltlineLightPool)->void:
 scene=source;camera=view;weapon=state;light_pool=shared_lights
 for gun in weapon.rigs:
  var node:MeshInstance3D=scene.source_nodes[weapon.rigs[gun].flash["$node"]]
  flashes[gun]={"node":node,"material":node.mesh.surface_get_material(0),"time":0.0,"duration":.05,"seed":0.0,"jet":1.0,"scale":Vector3.ONE,"roll":0.0}

func muzzle_world(gun:String)->Vector3:
 var rig:Dictionary=weapon.rigs[gun];var root:Node3D=scene.source_nodes[rig.root["$node"]]
 var muzzle:Array=rig.muzzle
 var local=root.transform*Vector3(muzzle[0],muzzle[1],muzzle[2])
 var ratio=tan(deg_to_rad(camera.fov)*.5)/tan(deg_to_rad(54)*.5)
 local.x*=ratio;local.y*=ratio
 return camera.global_transform*local

func flash_light(gun:String,definition:Dictionary)->void:
 light_pool.flash(muzzle_world(gun),0xffb060,definition.flashLight,9,.05)

func fire(gun:String,definition:Dictionary,emit_light:bool=true)->void:
 var flash:Dictionary=flashes[gun]
 flash.duration=.036+weapon.motion_randf()*.02;flash.time=flash.duration;flash.seed=weapon.motion_randf()*100
 flash.jet=(.6+weapon.motion_randf()*.6)*(1 if definition.auto else .25);flash.roll=(weapon.motion_randf()-.5)*.4
 var size=(.8+weapon.motion_randf()*.5)*(1.0+(.62-1.0)*weapon.ads)*definition.flashScale
 flash.scale=Vector3(size,size,size*(.8+weapon.motion_randf()*.5));flashes_emitted+=1
 if emit_light:flash_light(gun,definition)

func update(dt:float)->void:
 for gun in flashes:
  var flash:Dictionary=flashes[gun];flash.time-=dt
  if weapon.debug_flash and gun==weapon.current:
   flash.duration=.05;flash.time=.03;flash.seed=3.7;flash.scale=Vector3.ONE*float(weapon.rigs[gun].def.flashScale)
  var intensity=9.5*sqrt(flash.time/flash.duration) if flash.time>0 else (4.5 if weapon.last_shot==weapon.time and gun==weapon.current else 0.0)
  var heat=clampf((weapon.heat-.45)/.8,0,1)*2.2 if gun=="rifle" and gun==weapon.current else 0.0
  flash.material.set_shader_parameter("uSeed",flash.seed);flash.material.set_shader_parameter("uInt",intensity);flash.material.set_shader_parameter("uJet",flash.jet);flash.material.set_shader_parameter("uHeat",heat)
  flash.node.rotation=Vector3(0,0,flash.roll);flash.node.scale=flash.scale
  flash.node.visible=gun==weapon.current and (intensity>0 or heat>.02)

func clear()->void:
 for flash in flashes.values():
  flash.time=0;flash.node.visible=false;flash.material.set_shader_parameter("uInt",0);flash.material.set_shader_parameter("uHeat",0)
