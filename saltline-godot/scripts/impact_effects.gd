class_name SaltlineImpactEffects
extends Node3D

var pool:SaltlineParticles
var batch:SaltlineTracers
var camera:Camera3D
var ground_queries
var tracer_pool:SaltlineTracers
var tracer_trail_time=-1.0
var rng=preload("res://scripts/fx_random.gd").new()
var clock=0.0
var impact_flash_time=-1.0
var impacts=0
var maximum_live=0
var lit_pool:SaltlineParticles
var lit_batch:SaltlineTracers
var physics:SaltlinePhysics
var debris:SaltlineDebris
var light_pool:SaltlineLightPool
var enemy_muzzle_flashes=0
var fx_color=preload("res://scripts/fx_color.gd").new()

func setup(scene:SaltlineSourceScene,view:Camera3D,collision:SaltlinePhysics=null,random_stream=null)->void:
 camera=view
 if random_stream!=null:rng=random_stream
 pool=SaltlineParticles.new(3040,false,rng)
 batch=SaltlineTracers.new();add_child(batch);batch.setup(scene,view,false,rng)
 lit_pool=SaltlineParticles.new(1400,true,rng)
 lit_batch=SaltlineTracers.new();add_child(lit_batch);lit_batch.setup(scene,view,true,rng)
 physics=collision if collision!=null else SaltlinePhysics.new(scene.source.physics)
 debris=SaltlineDebris.new(scene,rng)

func ground_at(position:Vector3)->float:
 var hit=physics.raycast(position+Vector3(0,.1,0),Vector3.DOWN,12)
 return hit.point.y if not hit.is_empty() else -50.0

func fragments(position:Vector3,normal:Vector3,count:int,speed_min:float,speed_max:float,size_min:Vector3,size_max:Vector3,color:Vector3,spread:float,floor_override:Variant=null)->void:
 var floor_y=ground_at(position) if floor_override==null else float(floor_override)
 for i in count:
  var direction=scatter(normal,spread);var speed=rng.randf_range(speed_min,speed_max)
  var shade=rng.randf_range(.8,1.15)
  var size=Vector3(rng.randf_range(size_min.x,size_max.x),rng.randf_range(size_min.y,size_max.y),rng.randf_range(size_min.z,size_max.z))
  debris.emit(position+direction*.02,direction*speed+Vector3(0,.8,0),size,color*shade,rng.randf_range(3.5,6),floor_y)

func shade_at(position:Vector3,normal:Vector3)->float:
 var hit=physics.raycast(position+normal*.08+Vector3(0,.03,0),Vector3(.916,.225,.331).normalized(),90)
 return .2 if not hit.is_empty() else 1.0

func puff(position:Vector3,velocity:Vector3,life:float,start:float,end:float,color:Vector3,alpha:float,shade:float,drag:float,rise:float,wind:float,frame:int=-1)->Dictionary:
 var particle=lit_pool.emit(position,velocity,life,start,end)
 if particle.is_empty():return particle
 particle.merge({"color":color,"alpha":lit_pool.f32(alpha),"shade":lit_pool.f32(shade),"drag":lit_pool.f32(drag),"gravity":lit_pool.f32(-rise),"wind":lit_pool.f32(wind),"turbulence":lit_pool.f32(.5),"rotation":lit_pool.f32(rng.randf()*6.283),"rotation_speed":lit_pool.f32((rng.randf()-.5)*1.2),"frame":int(rng.randf()*6) if frame<0 else frame,"fade_in":lit_pool.f32(.06),"fade_out":lit_pool.f32(.3),"sk":lit_pool.f32(2.5)},true)
 return particle

func dust(position:Vector3,normal:Vector3,size:float,color:Vector3)->float:
 if normal.length_squared()<1e-6:normal=Vector3.UP
 normal=normal.normalized()
 var shade=shade_at(position,normal)
 for i in 8:
  var velocity=scatter(normal,.5)*rng.randf_range(1,4.5)*size
  var tint=rng.randf_range(.85,1.1)
  puff(position+normal*.03,velocity,rng.randf_range(.5,1.1),.08*size,rng.randf_range(.35,.7)*size,color*tint,.9,shade,3.5,.15,.6,7 if i<3 else -1)
 for i in 2:
  var velocity=Vector3(normal.x*.5+(rng.randf()-.5)*.3,normal.y*.5+.1,normal.z*.5+(rng.randf()-.5)*.3)
  puff(position+normal*.15,velocity,rng.randf_range(2.2,3.6),.25*size,rng.randf_range(.9,1.5)*size,color,.28,shade,1.5,.1,1)
 return shade

func tracer(origin:Vector3,end:Vector3,options:Dictionary={})->void:
 var channels=fx_color.parse(options.get("color"),PackedFloat64Array([1,.8,.46]))
 var intensity=float(options.get("intensity",16));var speed=float(options.get("speed",260));var width=float(options.get("width",.024))
 if intensity==0:intensity=16
 if speed==0:speed=260
 if width==0:width=.024
 tracer_pool.emit(origin,end,Vector3(channels[0]*intensity,channels[1]*intensity,channels[2]*intensity),speed,width)
 var trail=options.get("trail",null)
 if clock-tracer_trail_time<=.07 or (trail is bool and not trail):return
 tracer_trail_time=clock
 var dx=float(end.x)-origin.x;var dy=float(end.y)-origin.y;var dz=float(end.z)-origin.z
 var distance=sqrt(dx*dx+dy*dy+dz*dz)
 if distance<=2:return
 dx/=distance;dy/=distance;dz/=distance
 var extent=minf(distance,7);var shade=shade_at(origin,Vector3.ZERO)
 for i in 5:
  var offset=.6+(i+rng.randf())/5*(extent-.6)
  var particle=puff(Vector3(origin.x+dx*offset,origin.y+dy*offset,origin.z+dz*offset),Vector3(dx*.6,.05,dz*.6),rng.randf_range(.45,.8),.04,rng.randf_range(.12,.2),Vector3(.6,.6,.62),.1,shade,2,.1,.7)
  if not particle.is_empty():particle.fade_in=lit_pool.f32(.25)

func scatter(axis:Vector3,spread:float)->Vector3:
 var direction=scatter_components(axis,spread)
 return Vector3(direction[0],direction[1],direction[2])

func scatter_components(axis:Vector3,spread:float)->PackedFloat64Array:
 var x=rng.randf()*2-1;var y=rng.randf()*2-1;var z=rng.randf()*2-1
 var length=sqrt(x*x+y*y+z*z)
 if length==0:length=1
 var scale=spread*pow(rng.randf(),1.0/3)/length
 x=axis.x+x*scale;y=axis.y+y*scale;z=axis.z+z*scale
 length=sqrt(x*x+y*y+z*z)
 return PackedFloat64Array([axis.x,axis.y,axis.z]) if length<.0001 else PackedFloat64Array([x/length,y/length,z/length])


func _sparks(position:Vector3,axis:Vector3,count:int,speed_min:float,speed_max:float,spread:float,life_min:float,life_max:float,color:Vector3,flags:int)->void:
 for i in count:
  var direction=scatter(axis,spread)
  var speed=rng.randf_range(speed_min,speed_max)*(.35+.65*rng.randf())
  var life=rng.randf_range(life_min,life_max)
  var size=rng.randf_range(.01,.02)
  var red=color.x*rng.randf_range(.6,1.2)
  var green=color.y*rng.randf_range(.6,1.2)
  pool.emit(position,direction*speed,life,size,size*.5,{"mode":1,"frame":1,"stretch":.03,"gravity":9.81,"drag":.9,"ramp":1,"color":Vector3(red*.6,green*.6,color.z*.6),"fade_out":.55,"flags":flags,"sk":1})

func flash(position:Vector3,life:float,start:float,end:float,color:Vector3,frame:int=0)->Dictionary:
 var particle=pool.emit(position,Vector3.ZERO,life,start,end,{"frame":frame,"color":color,"fade_out":.2,"sk":1.5})
 if not particle.is_empty():particle.rotation=pool.f32(rng.randf()*6.283)
 return particle

func splash(position:Vector3,size:float=1)->void:
 var shade=shade_at(position,Vector3.UP)
 for i in 5:
  var extent=rng.randf_range(.35,.6)*size
  var offset=Vector3((rng.randf()-.5)*.08*size,.1*size,(rng.randf()-.5)*.08*size)
  var velocity=Vector3((rng.randf()-.5)*.5,rng.randf_range(1.6,2.8)*sqrt(size),(rng.randf()-.5)*.5)
  var particle=puff(position+offset,velocity,rng.randf_range(.4,.65),extent*.3,extent,Vector3(.72,.78,.84),.95,shade,.5,-7,0,6)
  if not particle.is_empty():
   particle.rotation=lit_pool.f32((rng.randf()-.5)*.3);particle.rotation_speed=0;particle.turbulence=0;particle.sk=3;particle.fade_out=lit_pool.f32(.4)
 for i in 2:
  puff(position+Vector3(0,.15*size,0),Vector3((rng.randf()-.5)*.6,.5,(rng.randf()-.5)*.6),rng.randf_range(.7,1.1),.2*size,.7*size,Vector3(.7,.75,.8),.14,shade,2,0,.8)
 for i in roundi(14*minf(size,1.6)):
  var direction=scatter(Vector3.UP,.75);var speed=rng.randf_range(1.5,4.8)*sqrt(size)
  pool.emit(position+Vector3(0,.03,0),Vector3(direction.x*speed,absf(direction.y)*speed,direction.z*speed),rng.randf_range(.5,1),rng.randf_range(.012,.024),.01,{"mode":1,"frame":6,"stretch":.012,"gravity":9.81,"drag":.4,"color":Vector3(1.9*shade+.35,1.5*shade+.45,1.05*shade+.55),"fade_out":.7,"flags":2,"sk":1,"floor":position.y})
 ripple(position+Vector3(0,.012,0),.9,.12*size,1.5*size,Vector3(.3*shade+.08,.27*shade+.09,.22*shade+.1))
 var second=ripple(position+Vector3(0,.012,0),1.3,.05*size,size,Vector3(.2*shade+.05,.18*shade+.06,.15*shade+.07))
 if not second.is_empty():second.fade_in=pool.f32(.35)

func ripple(position:Vector3,life:float,start:float,end:float,color:Vector3)->Dictionary:
 var particle=pool.emit(position,Vector3.ZERO,life,start,end,{"mode":2,"frame":4,"color":color,"fade_in":.08,"fade_out":.15,"sk":2.2})
 if not particle.is_empty():particle.rotation=pool.f32(rng.randf()*6.283)
 return particle

func impact(hit:Dictionary,direction:Vector3)->String:
 if hit.is_empty():return ""
 impacts+=1
 var normal:Vector3=hit.normal
 if normal.length_squared()<1e-6:normal=Vector3.UP
 normal=normal.normalized()
 var incoming=direction.normalized() if direction.length_squared()>1e-6 else -normal
 var reflected=incoming.bounce(normal).normalized()
 var surface=str(hit.surface)
 if ground_queries!=null and surface not in ["enemy","water"] and normal.y>.7:
  if ground_queries.is_puddle(hit.point.x,hit.point.z) and hit.point.y<.08:surface="water"
 var distant=camera.global_position.distance_squared_to(hit.point)>3025
 var scale=.5 if distant else 1.0
 if surface=="water":splash(hit.point,1)
 elif surface=="metal":
  var axis=(reflected+normal*.6).normalized()
  _sparks(hit.point,axis,roundi(18*scale),6,24,.55,.1,.38,Vector3(40,25,10.5),0)
  _sparks(hit.point,axis,2+int(rng.randf()*2),9,18,.9,.7,1.3,Vector3(32,18,7),1)
  flash(hit.point+normal*.03,.05,.25,.45,Vector3(16,11,5.5),0)
  flash(hit.point+normal*.04,.04,.35,.5,Vector3(9,6,2.6),2+int(rng.randf()*2))
  if clock-impact_flash_time>.09:
   impact_flash_time=clock
   if light_pool!=null:light_pool.flash(hit.point+normal*.12,16760944,10,5,.05)
  var shade=shade_at(hit.point,normal)
  for i in 2:
   puff(hit.point+normal*.04,Vector3(normal.x*.8+(rng.randf()-.5)*.5,normal.y*.8+.2,normal.z*.8+(rng.randf()-.5)*.5),rng.randf_range(.5,.9),.06,rng.randf_range(.3,.5),Vector3(.4,.4,.41),.4,shade,2.5,.3,.8)
  if not distant:fragments(hit.point,normal,2,1.5,4,Vector3(.012,.003,.01),Vector3(.03,.005,.025),Vector3(.2,.21,.23),.8)
 elif surface=="enemy":
  var axis=(reflected+normal*.8).normalized()
  _sparks(hit.point,axis,roundi(13*scale),5,20,.9,.12,.45,Vector3(42,29,14),0)
  _sparks(hit.point,axis,2,6,12,1,.6,1.1,Vector3(32,18,7),1)
  flash(hit.point,.06,.3,.55,Vector3(18,12,6),0)
  flash(hit.point,.04,.3,.45,Vector3(8,5,2.4),2+int(rng.randf()*2))
  if clock-impact_flash_time>.09:
   impact_flash_time=clock
   if light_pool!=null:light_pool.flash(hit.point,16756832,8,4.5,.05)
  var shade=shade_at(hit.point,normal)
  for j in 2:
   puff(hit.point,Vector3(normal.x*.5+(rng.randf()-.5)*.4,normal.y*.5+.3,normal.z*.5+(rng.randf()-.5)*.4),rng.randf_range(.6,1.1),.06,rng.randf_range(.3,.5),Vector3(.13,.13,.14),.65,shade,2.2,.5,.9)
  if not distant:
   var copper=rng.randf()<.35
   fragments(hit.point,normal,3,2,6,Vector3(.012,.004,.012),Vector3(.035,.008,.03),Vector3(.6,.2 if copper else .62,.05 if copper else .64),.8)
 elif surface=="wood":
  var shade=dust(hit.point,normal,.75,Vector3(.5,.42,.32))
  fragments(hit.point,normal,3 if distant else 7,2,6,Vector3(.004,.03,.004),Vector3(.009,.1,.012),Vector3(.62,.5,.33),.7)
  if shade>.5 and rng.randf()<.3:flash(hit.point,.04,.1,.2,Vector3(3,2,1))
 elif surface in ["rubber","dirt"]:
  var color=Vector3(.3,.25,.19) if surface=="dirt" else Vector3(.14,.14,.14)
  var shade=shade_at(hit.point,normal)
  for i in 5:
   puff(hit.point+normal*.03,scatter(normal,.6)*rng.randf_range(.6,2.6),rng.randf_range(.5,1),.07,rng.randf_range(.3,.55),color,.85,shade,3.5,.1,.6,7 if i<2 else -1)
  fragments(hit.point,normal,3,1.5,4,Vector3(.01,.008,.01),Vector3(.03,.02,.03),color*.8,.7)
 elif surface=="glass":
  for i in 12:
   pool.emit(hit.point,scatter(normal,.9)*rng.randf_range(1.5,6),rng.randf_range(.4,.9),rng.randf_range(.012,.02),.008,{"mode":1,"frame":6,"stretch":.01,"gravity":9.81,"color":Vector3(2.6,2.7,2.8),"flags":2,"ramp":3})
  fragments(hit.point,normal,4,1.5,5,Vector3(.01,.002,.01),Vector3(.03,.004,.03),Vector3(.62,.72,.74),.8)
  puff(hit.point,normal*.6+Vector3(0,.2,0),.6,.08,.4,Vector3(.75,.8,.82),.2,shade_at(hit.point,normal),2.5,.2,.8)
 elif surface not in ["water","rubber","dirt","glass","enemy"]:
  dust(hit.point,normal,1,Vector3(.52,.5,.47))
  fragments(hit.point,normal,2 if distant else 4,1.5,5.5,Vector3(.012,.008,.012),Vector3(.035,.02,.035),Vector3(.42,.41,.39),.7)
  var axis=(reflected+normal*.7).normalized()
  for i in 4:
   var particle=puff(hit.point,scatter(axis,.5)*rng.randf_range(3,9),rng.randf_range(.25,.45),.03,.09,Vector3(.6,.58,.54),.7,1,2,-6,.2,7)
   if not particle.is_empty():particle.turbulence=0
  if rng.randf()<.3:_sparks(hit.point,axis,3,4,10,.6,.08,.2,Vector3(26,15,6),0)
 return surface

func player_motion_event(kind:String,payload:Dictionary,player_position:Vector3)->void:
 if kind=="step":
  var position:Vector3=payload.get("pos",player_position)
  if payload.get("surface","")=="water" or (ground_queries!=null and ground_queries.is_puddle(position.x,position.z)):
   splash(Vector3(position.x,maxf(0,position.y),position.z),.55 if payload.get("sprint",false) else .4)
 elif kind=="land":
  var position=Vector3(player_position.x,maxf(0,player_position.y),player_position.z)
  if payload.get("surface","")=="water" or (ground_queries!=null and ground_queries.is_puddle(player_position.x,player_position.z)):
   splash(position,.9)
  elif float(payload.get("speed",0))>5:
   var shade=shade_at(position,Vector3.UP)
   for i in 6:
    var angle=rng.randf()*6.283
    puff(position+Vector3(cos(angle)*.2,.08,sin(angle)*.2),Vector3(cos(angle)*1.6,.3,sin(angle)*1.6),rng.randf_range(.7,1.2),.15,rng.randf_range(.5,.8),Vector3(.45,.44,.42),.22,shade,3,.1,.8)

func update(dt:float,advance_clock:bool=true)->void:
 if not (dt>0):dt=0
 if advance_clock:clock+=dt
 lit_batch.draw_source_quads(lit_pool.update(dt,camera.global_position,Vector3(-.8,0,.3),clock))
 var quads=pool.update(dt,camera.global_position,Vector3(-.8,0,.3),clock)
 maximum_live=maxi(maximum_live,pool.particles.size())
 batch.draw_source_quads(quads)
 if tracer_pool!=null:tracer_pool.update(dt)
 debris.update(dt)

# Original generic fx.smoke and fx.sparks used by enemy damage/death.
func smoke(position:Vector3,options:Dictionary={})->void:
 var truth=preload("res://scripts/source_settings.gd")
 var size=float(options.size) if truth.truthy(options.get("size")) else 1.0
 var life=float(options.life) if truth.truthy(options.get("life")) else 2.5
 var alpha=float(options.alpha) if truth.truthy(options.get("alpha")) else .4
 var count=float(options.count) if truth.truthy(options.get("count")) else 3.0
 var rise=0.0 if options.get("rise",.6)==null else float(options.get("rise",.6))
 var source_color=fx_color.parse(options.get("color"))
 var color=Vector3(source_color[0],source_color[1],source_color[2]);var shade=shade_at(position,Vector3.ZERO)
 var i=0
 while float(i)<count:
  var origin=Vector3(position.x+(rng.randf()-.5)*.2*size,position.y+(rng.randf()-.5)*.2*size,position.z+(rng.randf()-.5)*.2*size)
  var base:Vector3=options.get("vel",Vector3.ZERO)
  var velocity=Vector3(base.x+(rng.randf()-.5)*.4,base.y+rng.randf()*.3,base.z+(rng.randf()-.5)*.4)
  puff(origin,velocity,life*rng.randf_range(.75,1.2),size*.3,size*rng.randf_range(1,1.5),color,alpha,shade,1.2,rise,1)
  i+=1

func sparks(position:Vector3,normal:Vector3=Vector3.UP,count:int=12)->void:
 if normal.length_squared()<1e-6:normal=Vector3.UP
 normal=normal.normalized();_sparks(position,normal,count,5,18,.6,.15,.5,Vector3(36,22,9),1)
 flash(position,.05,.2,.35,Vector3(10,6.5,3),0)

func muzzle_flash(position:Vector3,direction:Vector3=Vector3.UP,options:Dictionary={})->void:
 var scale=float(options.scale) if preload("res://scripts/source_settings.gd").truthy(options.get("scale")) else 1.0
 enemy_muzzle_flash(position,direction,scale,options.get("color"))

func enemy_muzzle_flash(position:Vector3,direction:Vector3,scale:float=1,color_input:Variant=null)->void:
 if scale==0:scale=1
 if direction.length_squared()<1e-6:direction=Vector3.FORWARD
 direction=direction.normalized();enemy_muzzle_flashes+=1
 var channels=fx_color.parse(color_input,PackedFloat64Array([1,.68,.32]))
 var color=Vector3(channels[0],channels[1],channels[2])
 var layers=[
  [.1*scale,.045,.75*scale,1.15*scale,color*34,2],
  [.14*scale,.035,.5*scale,.85*scale,color*22,3],
  [.05*scale,.045,.13*scale,.2*scale,Vector3(22,22*(color.y+.25),22*(color.z+.3)),0],
  [0,.05,.8*scale,1.1*scale,color*.4,0]]
 for layer in layers:
  flash(position+direction*layer[0],layer[1],layer[2],layer[3],layer[4],layer[5])
 pool.emit(position+direction*.4*scale,-direction,.04,.11*scale,.14*scale,{"mode":1,"frame":7,"stretch":.9*scale,"color":color*18,"fade_out":.3})
 for i in 3:
  var velocity=scatter(direction,.25)*rng.randf_range(8,22)
  pool.emit(position,velocity,rng.randf_range(.08,.22),.012,.006,{"mode":1,"frame":1,"stretch":.03,"gravity":9.81,"drag":.9,"ramp":1,"color":Vector3(18,10.8,4.2),"fade_out":.55,"flags":0,"sk":1})
 puff(position+direction*.2,direction*1.5+Vector3(0,.2,0),rng.randf_range(.5,.9),.08*scale,.45*scale,Vector3(.5,.5,.52),.16,1,3,.3,.8)
 if light_pool!=null:light_pool.flash(position+direction*.25,16756832,16*scale,7*scale,.05)

func clear()->void:
 pool.clear();lit_pool.clear();debris.clear();batch.draw_source_quads([]);lit_batch.draw_source_quads([])
 if tracer_pool!=null:tracer_pool.clear()
