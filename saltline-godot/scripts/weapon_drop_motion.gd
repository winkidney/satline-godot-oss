extends RefCounted
# Original oe/le/xe/j numeric stage. Renderer reparent/layers and arm drop are adapters.
var math=preload("res://scripts/weapon_arm_ik.gd").new()
var active=false
var gun=""
var time=0.0
var position=[0.0,0.0,0.0]
var rotation=[0.0,0.0,0.0,1.0]
var velocity=[0.0,0.0,0.0]
var angular=[0.0,0.0,0.0]
var resting=false
var sunk=false
var visible=true
var bounces=0
var heard=0
var rest_time=0.0
var rest_rotation=[0.0,0.0,0.0,1.0]
var euler_order="XYZ"
var random_source:Callable
var splash:Callable
var random_calls=0
func _init(random:Callable)->void:random_source=random
func random()->float:
 random_calls+=1;return random_source.call()
func euler(x:float,y:float,z:float,order:String)->Array:
 var c1=cos(x/2);var c2=cos(y/2);var c3=cos(z/2);var s1=sin(x/2);var s2=sin(y/2);var s3=sin(z/2)
 if order=="YXZ":return [s1*c2*c3+c1*s2*s3,c1*s2*c3-s1*c2*s3,c1*c2*s3-s1*s2*c3,c1*c2*c3+s1*s2*s3]
 return [s1*c2*c3+c1*s2*s3,c1*s2*c3-s1*c2*s3,c1*c2*s3+s1*s2*c3,c1*c2*c3-s1*s2*s3]
func rotate(v:Array,q:Array)->Array:
 var t=math.scale(math.cross([q[0],q[1],q[2]],v),2)
 return math.add(v,math.add(math.scale(t,q[3]),math.cross([q[0],q[1],q[2]],t)))
func slerp(a:Array,b:Array,t:float)->Array:
 var dot=a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3];var target=b.duplicate()
 if dot<0:
  dot=-dot
  for j in 4:target[j]=-target[j]
 if dot>=1:return a.duplicate()
 var square=1-dot*dot;var first=1-t;var second=t
 if square>2.220446049250313e-16:
  var sine=sqrt(square);var angle=atan2(sine,dot);first=sin((1-t)*angle)/sine;second=sin(t*angle)/sine
 var result=[];var length=0.0
 for j in 4:result.append(a[j]*first+target[j]*second);length+=result[j]*result[j]
 if square<=2.220446049250313e-16:
  length=sqrt(length)
  for j in 4:result[j]/=length
 return result
func start(id:String,local_p:Array,local_q:Array,camera_p:Array,camera_q:Array,camera_fov:float,view_fov:float,player_velocity:Array,arm_start:Callable=Callable())->bool:
 if active:return false
 if arm_start.is_valid():arm_start.call(random_source)
 var ratio=tan(deg_to_rad(camera_fov)/2)/tan(deg_to_rad(view_fov)/2)
 var p=local_p.duplicate();p[2]/=ratio
 position=math.add(rotate(p,camera_q),camera_p);rotation=math.mul(camera_q,local_q)
 velocity=math.add(rotate([.35+random()*.3,.5,-.5-random()*.4],camera_q),math.scale(player_velocity,.6))
 angular=[2.2+random()*1.5,(random()-.5)*3,-(3+random()*2)]
 active=true;gun=id;time=0.0;resting=false;sunk=false;bounces=0;heard=0;visible=true
 return true
func step(dt:float,raycast:Callable,ground:Callable,arm_step:Callable=Callable())->void:
 if not active:return
 time+=dt
 if arm_step.is_valid():arm_step.call(dt)
 if not resting and not sunk:
  var count=maxi(1,int(ceil(dt/.012)));var delta=dt/count
  for j in count:
   velocity[1]-=13.5*delta
   var horizontal=sqrt(velocity[0]*velocity[0]+velocity[2]*velocity[2])
   if horizontal>.05:
    var direction=[velocity[0]/horizontal,0.0,velocity[2]/horizontal]
    if raycast.call(position.duplicate(),direction,horizontal*delta+.12)!=null:velocity[0]*=-.2;velocity[2]*=-.2
   position=math.add(position,math.scale(velocity,delta))
   rotation=math.mul(rotation,euler(angular[0]*delta,angular[1]*delta,angular[2]*delta,euler_order))
   var floor_height=float(ground.call(position[0],position[2],position[1]+.4))
   if not floor_height> -1.5:
    if position[1]<-1.7:
     sunk=true;visible=false
     if splash.is_valid():splash.call(position.duplicate(),.8)
    continue
   if position[1]<floor_height+.045 and velocity[1]<0:
    position[1]=floor_height+.045
    var speed=-velocity[1]
    # Preserve original bounce-audio RNG draws without producing audio.
    if heard<=3:heard+=1;random();random()
    bounces+=1
    if speed<1.1 or bounces>=3:
     var forward=rotate([0.0,0.0,-1.0],rotation);var yaw=atan2(-forward[0],-forward[2])
     var sign=1.0 if rotate([1.0,0.0,0.0],rotation)[1]>0 else -1.0
     euler_order="YXZ";rest_rotation=euler(0,yaw,sign*(PI/2-.06),euler_order)
     resting=true;rest_time=0.0;velocity=[0.0,0.0,0.0]
     break
    velocity[1]=speed*.3;velocity[0]*=.55;velocity[2]*=.55
    angular=math.scale(angular,.55);angular[0]+=(random()-.5)*3
 if not resting or sunk:return
 rest_time+=dt
 if rest_time>.5:return
 rotation=slerp(rotation,rest_rotation,1-exp(-16*dt))
 var floor_height=float(ground.call(position[0],position[2],position[1]+.4))
 position[1]=floor_height+.024+(position[1]-(floor_height+.024))*exp(-18*dt)
func restore()->void:
 if not active:return
 visible=false;active=false;gun=""
