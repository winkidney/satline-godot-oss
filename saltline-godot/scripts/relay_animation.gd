class_name SaltlineRelayAnimation
extends RefCounted

var state="live"
var phase=0.0
var cut_time=0.0
var spin_speed=.7
var hinge=0.0
var hinge_velocity=0.0
var hinge_target=0.0
var level=6.0
var color_hex=16752680
var spin_delta=0.0
var hinge_delta=0.0

func _init(seed:int,initial_time:float=0)->void:phase=(seed%7)*.9+initial_time
func set_state(value:String)->void:
 if value not in ["live","cutting","cut"] or value==state:return
 state=value
 if value=="cut":cut_time=0;hinge_target=1.32;hinge_velocity=2.5
 elif value=="live":hinge_target=0

func update(dt:float)->void:
 dt=minf(dt,.1);phase+=dt;level=0;color_hex=16752680;var target_speed=.7
 if state=="live":level=5.5+3*sin(phase*2.2)
 elif state=="cutting":
  var bright=sin(phase*2*PI*5.5)>0;level=9 if bright else .5;color_hex=16767392 if bright else 16752680;target_speed=2.6+sin(phase*9)*1.5
 else:
  cut_time+=dt;color_hex=16721940;target_speed=0
  if cut_time<.3:level=9
  elif cut_time<2.6:
   var fade=1-(cut_time-.3)/2.3;level=7*fade*fade*(1 if sin(cut_time*37)*sin(cut_time*13.3)>-.2 else .08)
 spin_speed+=(target_speed-spin_speed)*minf(1,dt*(1.6 if state=="cut" else 3));spin_delta=spin_speed*dt if absf(spin_speed)>.001 else 0;hinge_delta=0
 if absf(hinge_target-hinge)>1e-4 or absf(hinge_velocity)>.001:
  hinge_velocity+=(-(hinge-hinge_target)*30-hinge_velocity*3.2)*dt
  var next=hinge+hinge_velocity*dt
  if next<0:next=0;hinge_velocity=absf(hinge_velocity)*.3
  if next>1.9:next=1.9;hinge_velocity=-absf(hinge_velocity)*.4
  hinge_delta=next-hinge;hinge=next
