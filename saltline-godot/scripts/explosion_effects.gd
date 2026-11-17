class_name SaltlineExplosionEffects
extends RefCounted

signal exploded(position:Vector3,size:float)
var fx:SaltlineImpactEffects
var decals:SaltlineDecals
var lights:SaltlineLightPool
var rng=preload("res://scripts/fx_random.gd").new()
var emitter_slots:Array=[]
var emitters:Array:
 get:return emitter_slots.filter(func(emitter):return emitter.active)
var count=0
var overflow_emitter={"active":false}

func _init(effects:SaltlineImpactEffects,decal_pool:SaltlineDecals,light_pool:SaltlineLightPool,random_stream=null)->void:
 fx=effects;decals=decal_pool;lights=light_pool;rng=random_stream if random_stream!=null else effects.rng
 for i in 24:emitter_slots.append({"active":false,"kind":"steam","position":Vector3.ZERO,"position64":PackedFloat64Array([0,0,0]),"ttl":INF,"scale":1.0,"shade":1.0,"time":0.0,"accumulator":0.0,"accumulator2":0.0,"drop":-1.0,"light":null})

func flash(position:Vector3,life:float,start:float,end:float,color:Vector3,frame:int=0)->void:
 fx.flash(position,life,start,end,color,frame)

func explode(position:Vector3,size:float=1)->void:
 count+=1
 var q=clampf(size,.4,4);var root=sqrt(q)
 var floor_y=fx.ground_at(position);var grounded=position.y-floor_y<1.4*q
 var shade=fx.shade_at(position,Vector3.UP)
 var light_position=position+Vector3(0,.4,0)
 lights.flash(light_position,0xffe2b0,320*q,10+9*q,.08)
 lights.flash(light_position,0xff8a30,55*q,8+6*q,.45)
 var center=position+Vector3(0,.35*q,0)
 flash(center,.055,1.5*q,2.3*q,Vector3(16,13.5,9.5))
 flash(center,.05,2.6*q,4.2*q,Vector3(7,5,2.4),2+int(rng.randf()*2))
 flash(center,.3,3.5*q,5.5*q,Vector3(.35,.2,.08))
 for i in roundi(13+5*q):
  var direction=fx.scatter(Vector3.UP,1.6)
  if grounded and direction.y<-.1:direction.y=-direction.y*.5
  var speed=rng.randf_range(2.2,7.5)*root;var variation=rng.randf_range(.7,1.15)
  var particle=fx.lit_pool.emit(center+direction*.3*q,direction*speed+Vector3(0,1.4,0),rng.randf_range(.55,1.05),.85*q,rng.randf_range(1.8,2.7)*q,{"ramp":2,"color":Vector3(5.8,2.4,.5)*variation,"alpha":.96,"shade":2+shade,"drag":4,"gravity":-2.6,"wind":.6,"turbulence":1.5,"sk":3,"fade_in":0,"fade_out":.6})
  if not particle.is_empty():
   particle.frame=7 if i%4==0 else int(rng.randf()*6)
   particle.rotation=fx.lit_pool.f32(rng.randf()*6.283)
   particle.rotation_speed=fx.lit_pool.f32((rng.randf()-.5)*2.5)
 for i in 5:
  var direction=fx.scatter(Vector3.UP,1.4);var speed=rng.randf_range(2,5)*root
  var particle=fx.pool.emit(center+direction*.3*q,Vector3(direction.x*speed,absf(direction.y)*speed+1.2,direction.z*speed),rng.randf_range(.3,.55),.6*q,rng.randf_range(1.2,1.8)*q,{"frame":5,"ramp":2,"color":Vector3(2.4,1.1,.3),"drag":4,"gravity":-2.5,"sk":3,"fade_out":.4})
  if not particle.is_empty():particle.rotation=fx.pool.f32(rng.randf()*6.283)
 for i in roundi(11+5*q):
  var outer=i%2==0;var direction=fx.scatter(Vector3.UP,1.4)
  if grounded and direction.y<0:direction.y=-direction.y*.4
  var speed=(rng.randf_range(4.5,9) if outer else rng.randf_range(1.5,5))*root
  var tone=rng.randf_range(.04,.1);var distance=.75 if outer else .3
  var particle=fx.puff(center+direction*distance*q,direction*speed+Vector3(0,.8,0),rng.randf_range(2.8,4.8),(.8 if outer else 1.2)*q,rng.randf_range(2.6,4.2)*q,Vector3(tone,tone*.95,tone*.9),.7 if outer else .8,shade,3.4,rng.randf_range(.8,1.7),1,7 if i%3==0 else -1)
  if not particle.is_empty():particle.fade_in=fx.lit_pool.f32(.025 if outer else .16);particle.fade_out=fx.lit_pool.f32(.35);particle.turbulence=fx.lit_pool.f32(1.2)
 _start_smolder(position+Vector3(0,.3*q,0),1.3+.3*q,q,shade)
 for i in mini(90,roundi(34*q)):
  var direction=fx.scatter_components(Vector3.UP,1.5)
  if grounded and direction[1]<0:direction[1]=-direction[1]
  var speed=rng.randf_range(6,26)*root;var life=rng.randf_range(.5,1.5);var width=rng.randf_range(.014,.028)
  fx.pool.emit(position+Vector3(0,.05,0),Vector3(direction[0]*speed,direction[1]*speed,direction[2]*speed),life,width,width*.5,{"mode":1,"frame":1,"stretch":.035,"gravity":9.81,"drag":1.4,"ramp":1,"color":Vector3(24,13.8,4.8),"fade_out":.55,"flags":1,"sk":1})
 for i in int(ceil(10*q)):
  var direction=fx.scatter(Vector3.UP,1.2);var speed=rng.randf_range(1,5)
  fx.pool.emit(position+Vector3(0,.3,0),Vector3(direction.x*speed,absf(direction.y)*speed+1,direction.z*speed),rng.randf_range(1.4,3),.035,.02,{"frame":0,"ramp":3,"color":Vector3(9,4,1),"drag":1.2,"gravity":.6,"turbulence":3,"wind":1,"fade_out":.5})
 if grounded:
  var y=floor_y+.015
  fx.ripple(Vector3(position.x,y,position.z),.32,.6*q,9*q,Vector3(1.6,1.2,.75))
  var total=roundi(12+3*q)
  for i in total:
   var angle=(i+rng.randf())/total*6.283;var speed=rng.randf_range(5,10)*root;var tone=rng.randf_range(.42,.55)
   var direction=Vector3(cos(angle),0,sin(angle))
   var particle=fx.puff(Vector3(position.x,y+.2,position.z)+direction*.4*q,direction*speed+Vector3(0,rng.randf_range(.2,.9),0),rng.randf_range(1.2,2.2),.4*q,rng.randf_range(1.2,1.9)*q,Vector3(tone,tone*.96,tone*.9),.26,shade,3,.15,.7)
   if not particle.is_empty():particle.fade_in=fx.lit_pool.f32(.1)
  decals.add(Vector3(position.x,floor_y,position.z),Vector3.UP,"scorch",2.3*q,1,.92)
 fx.fragments(Vector3(position.x,maxf(position.y,floor_y+.1),position.z),Vector3.UP,roundi(13+6*q),4,13*root,Vector3(.04,.025,.04),Vector3(.13,.08,.13),Vector3(.07,.066,.062),1.1,floor_y)
 exploded.emit(position,size)

func _start_smolder(position:Vector3,ttl:float,scale:float,shade:float)->Dictionary:
 return _start_emitter(position,"smolder",ttl,scale,shade)

func add_emitter(position:Variant,kind:String="steam",options:Dictionary={})->Dictionary:
 var ttl=float(options.get("ttl",INF));var scale=float(options.get("scale",1))
 if ttl==0:ttl=INF
 if scale==0:scale=1
 return _start_emitter(position,kind,ttl,scale)

func _start_emitter(position:Variant,kind:String,ttl:float,scale:float,shade:Variant=null)->Dictionary:
 var coordinates=PackedFloat64Array([position.x,position.y,position.z]) if position is Vector3 else PackedFloat64Array(position)
 var point=Vector3(coordinates[0],coordinates[1],coordinates[2])
 for emitter in emitter_slots:
  if not emitter.active:
   emitter.merge({"active":true,"kind":kind,"position":point,"position64":coordinates,"ttl":ttl,"scale":scale,"shade":fx.shade_at(point,Vector3.ZERO) if shade==null else shade,"time":0.0,"accumulator":0.0,"accumulator2":0.0,"drop":-1.0},true)
   if kind=="fire":
    var light=lights.acquire() if lights!=null else {}
    emitter.light=null if light.is_empty() else light
    if emitter.light!=null:
     light.light.light_color=Color.hex((16747066<<8)|255);light.light.omni_range=9;light.light.global_position=Vector3(coordinates[0],coordinates[1]+.5,coordinates[2])
   return emitter
 return overflow_emitter

func stop_emitter(emitter:Dictionary)->void:
 emitter.active=false
 if emitter.get("light")!=null:lights.release(emitter.light);emitter.light=null
func set_emitter_position(emitter:Dictionary,position:Variant)->void:
 if emitter.has("position"):
  var coordinates=PackedFloat64Array([position.x,position.y,position.z]) if position is Vector3 else PackedFloat64Array(position)
  emitter.position64=coordinates;emitter.position=Vector3(coordinates[0],coordinates[1],coordinates[2])

func _steam(emitter:Dictionary,dt:float)->void:
 emitter.accumulator+=dt*13
 while emitter.accumulator>1:
  emitter.accumulator-=1
  var p=emitter.position64;var scale=float(emitter.scale)
  var position=Vector3(p[0]+(rng.randf()-.5)*.08,p[1],p[2]+(rng.randf()-.5)*.08)
  var velocity=Vector3((rng.randf()-.5)*.4,rng.randf_range(1.4,2.4),(rng.randf()-.5)*.4)
  var particle=fx.puff(position,velocity,rng.randf_range(1.8,3),.12*scale,rng.randf_range(.8,1.3)*scale,Vector3(.8,.82,.85),.2,emitter.shade,1.3,.5,1)
  if not particle.is_empty():particle.fade_in=fx.lit_pool.f32(.12);particle.turbulence=fx.lit_pool.f32(.9)

func _embers(emitter:Dictionary,dt:float)->void:
 emitter.accumulator+=dt*8
 while emitter.accumulator>1:
  emitter.accumulator-=1
  var p=emitter.position64;var scale=float(emitter.scale)
  var position=Vector3(p[0]+(rng.randf()-.5)*.4*scale,p[1],p[2]+(rng.randf()-.5)*.4*scale)
  var velocity=Vector3((rng.randf()-.5)*.6,rng.randf_range(.6,1.8),(rng.randf()-.5)*.6)
  fx.pool.emit(position,velocity,rng.randf_range(1.5,3.2),rng.randf_range(.02,.04),.012,{"frame":0,"ramp":3,"color":Vector3(10,4.2,1),"drag":.8,"gravity":-.5,"turbulence":3.5,"wind":1,"fade_out":.5})

func _fire(emitter:Dictionary,dt:float)->void:
 var p=emitter.position64;var scale=float(emitter.scale)
 emitter.accumulator+=dt*24
 while emitter.accumulator>1:
  emitter.accumulator-=1
  var position=Vector3(p[0]+(rng.randf()-.5)*.3*scale,p[1]+.1*scale,p[2]+(rng.randf()-.5)*.3*scale)
  var velocity=Vector3((rng.randf()-.5)*.5,rng.randf_range(1.2,2.6)*scale,(rng.randf()-.5)*.5)
  var particle=fx.pool.emit(position,velocity,rng.randf_range(.35,.65),.45*scale,rng.randf_range(.2,.35)*scale,{"frame":5,"ramp":2,"color":Vector3(9,5.5,2.2),"drag":1,"fade_in":.12,"fade_out":.4,"wind":1,"turbulence":2})
  if not particle.is_empty():particle.rotation=fx.pool.f32(rng.randf()*6.283);particle.rotation_speed=fx.pool.f32((rng.randf()-.5)*4)
 emitter.accumulator2+=dt*4
 while emitter.accumulator2>1:
  emitter.accumulator2-=1
  var tone=rng.randf_range(.05,.1)
  var velocity=Vector3((rng.randf()-.5)*.4,rng.randf_range(1.2,2),(rng.randf()-.5)*.4)
  var particle=fx.puff(Vector3(p[0],p[1]+.8*scale,p[2]),velocity,rng.randf_range(2.2,3.4),.3*scale,rng.randf_range(1.1,1.8)*scale,Vector3.ONE*tone,.5,emitter.shade,.9,.8,1)
  if not particle.is_empty():particle.fade_in=fx.lit_pool.f32(.2);particle.turbulence=fx.lit_pool.f32(1)
  var position=Vector3(p[0]+(rng.randf()-.5)*.3,p[1]+.3,p[2]+(rng.randf()-.5)*.3)
  velocity=Vector3(rng.randf()-.5,rng.randf_range(1.5,3),rng.randf()-.5)
  fx.pool.emit(position,velocity,rng.randf_range(1,2.2),.03,.012,{"frame":0,"ramp":3,"color":Vector3(10,4.2,1),"drag":.8,"gravity":-.6,"turbulence":4,"wind":1})
 if emitter.light!=null:lights.set_energy(emitter.light,(14+6*sin(emitter.time*23)+4*sin(emitter.time*37.7))*scale)

func _drip(emitter:Dictionary,dt:float)->void:
 var p=emitter.position64;var shade=float(emitter.shade)
 emitter.accumulator+=dt*1.6
 if emitter.drop>=0:
  emitter.drop-=dt
  if emitter.drop<0:
   fx.ripple(Vector3(p[0],.014,p[2]),.8,.05,.55,Vector3(.4*shade+.14,.36*shade+.16,.3*shade+.18))
   for i in 3:
    var direction=fx.scatter_components(Vector3.UP,.7)
    fx.pool.emit(Vector3(p[0],.03,p[2]),Vector3(direction[0]*1.2,absf(direction[1])*1.6,direction[2]*1.2),.35,.012,.008,{"mode":1,"frame":6,"stretch":.012,"gravity":9.81,"color":Vector3(1.6*shade+.3,1.3*shade+.4,.9*shade+.5),"flags":2})
 while emitter.accumulator>1:
  emitter.accumulator-=1+rng.randf()*.6
  var fall=sqrt(2*maxf(p[1],.05)/9.81)
  fx.pool.emit(Vector3(p[0],p[1],p[2]),Vector3(0,-.2,0),fall+.05,.014,.014,{"mode":1,"frame":6,"stretch":.02,"gravity":9.81,"color":Vector3(1.4*shade+.4,1.2*shade+.5,.9*shade+.6),"flags":2,"fade_out":.98})
  emitter.drop=fall

func update(dt:float)->void:
 if not (dt>0):dt=0
 for emitter in emitter_slots:
  if not emitter.active:continue
  emitter.time+=dt
  if emitter.time>emitter.ttl:
   stop_emitter(emitter);continue
  if emitter.kind=="steam":_steam(emitter,dt);continue
  if emitter.kind=="embers":_embers(emitter,dt);continue
  if emitter.kind=="fire":_fire(emitter,dt);continue
  if emitter.kind=="drip":_drip(emitter,dt);continue
  if emitter.kind!="smolder":continue
  emitter.accumulator+=dt*9*(1-emitter.time/emitter.ttl)
  while emitter.accumulator>1:
   emitter.accumulator-=1
   var tone=rng.randf_range(.05,.11);var scale=float(emitter.scale)
   var offset=Vector3((rng.randf()-.5)*.5*scale,0,(rng.randf()-.5)*.5*scale)
   var particle=fx.puff(emitter.position+offset,Vector3((rng.randf()-.5)*.6,rng.randf_range(1.2,2.4),(rng.randf()-.5)*.6),rng.randf_range(2.4,3.8),.5*scale,rng.randf_range(1.6,2.6)*scale,Vector3.ONE*tone,.6,emitter.shade,1,.9,1)
   if not particle.is_empty():particle.fade_in=fx.lit_pool.f32(.12);particle.turbulence=1

func clear()->void:
 for emitter in emitter_slots:
  if emitter.active:stop_emitter(emitter)
