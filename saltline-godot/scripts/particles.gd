class_name SaltlineParticles
extends RefCounted

var capacity:int
var sorted:bool
var particles:Array=[]
var emitted=0
var dropped=0
var rng=preload("res://scripts/fx_random.gd").new()
var quads:Array=[]

func _init(limit:int=3040,sort_back_to_front:bool=false,random_stream=null)->void:
 capacity=limit;sorted=sort_back_to_front
 if random_stream!=null:rng=random_stream

func emit(position:Vector3,velocity:Vector3,life:float,start_size:float,end_size:float,options:Dictionary={})->Dictionary:
 if particles.size()>=capacity:dropped+=1;return {}
 var p={"position":position,"velocity":velocity,"age":-1.0,"life":life,"s0":start_size,"s1":end_size,"sk":2.0,"rotation":0.0,"rotation_speed":0.0,"color":Vector3.ONE,"alpha":1.0,"drag":0.0,"gravity":0.0,"wind":0.0,"turbulence":0.0,"seed":rng.randf()*100,"fade_in":0.0,"fade_out":.5,"stretch":.02,"shade":1.0,"floor":0.0,"frame":0,"mode":0,"flags":0,"ramp":0}
 p.merge(options,true)
 for key in ["frame","mode","flags","ramp"]:p[key]=int(p[key])
 for key in ["age","life","s0","s1","sk","rotation","rotation_speed","alpha","drag","gravity","wind","turbulence","seed","fade_in","fade_out","stretch","shade","floor"]:p[key]=f32(p[key])
 particles.append(p);emitted+=1;return p

func clear()->void:
 particles.clear();quads.clear()

func f32(value:float)->float:
 return PackedFloat32Array([value])[0]

func update(dt:float,camera_position:Vector3,wind:Vector3,clock:float)->Array:
 var alive=[]
 for p in particles:
  if p.age<0:p.age=0
  else:
   p.age=f32(p.age+dt)
   if p.age>=p.life:continue
   var drag=1-exp(-p.drag*dt)
   p.velocity+=(wind*p.wind-p.velocity)*drag;p.velocity.y-=p.gravity*dt
   if p.turbulence>0:
    p.velocity.x+=sin(p.position.y*2.3+p.seed+clock*1.7)*p.turbulence*dt
    p.velocity.z+=cos(p.position.x*1.9+p.seed*1.3+clock*1.3)*p.turbulence*dt
    p.velocity.y+=sin(p.position.z*2.1+p.seed*.7+clock*2.1)*p.turbulence*.4*dt
   p.position+=p.velocity*dt;p.rotation=f32(p.rotation+p.rotation_speed*dt)
   if p.flags and p.position.y<p.floor+.012:
    if p.flags&2:continue
    if p.flags&1:
     p.position.y=p.floor+.012
     if p.velocity.y<0:
      p.velocity.y=-p.velocity.y*(.25+fmod(p.seed,1)*.3);p.velocity.x*=.65;p.velocity.z*=.65
    elif p.flags&4:p.position.y=p.floor+.012;p.velocity=Vector3.ZERO
  p.distance_squared=p.position.distance_squared_to(camera_position);alive.append(p)
 particles=alive
 if sorted:
  for i in range(1,particles.size()):
   var current=particles[i];var j=i-1
   while j>=0 and particles[j].distance_squared<current.distance_squared:
    particles[j+1]=particles[j];j-=1
   particles[j+1]=current
 quads=[]
 for p in particles:
  var age=p.age/p.life;var remaining=1-age
  var size=lerpf(p.s0,p.s1,1-pow(remaining,p.sk))
  var alpha=float(p.alpha)
  if p.fade_in>0 and age<p.fade_in:alpha*=age/p.fade_in
  if age>p.fade_out:
   var fraction=1-(age-p.fade_out)/(1-p.fade_out);alpha*=fraction*fraction*(3-2*fraction)
  var color:Vector3=p.color
  if p.ramp==1:color*=Vector3(pow(remaining,.5),pow(remaining,1.4),pow(remaining,3))
  elif p.ramp==2:
   var heat=1-pow(age,1.6);var intensity=heat*sqrt(heat)
   color*=Vector3(intensity,(.22+.78*pow(heat,1.3))*intensity,(.04+.96*pow(heat,3.5))*intensity)
  elif p.ramp==3:
   var flicker=.55+.45*sin(clock*17+p.seed*9);color*=Vector3(flicker,flicker*(.6+.4*remaining),flicker*remaining)
  var axis:Vector3=p.velocity*p.stretch if p.mode==1 else Vector3.UP
  quads.append([p.position.x,p.position.y,p.position.z,size,axis.x,axis.y,axis.z,p.rotation,color.x,color.y,color.z,alpha,p.frame,p.mode,age,p.shade])
 return quads
