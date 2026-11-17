class_name SaltlineSkyWeather
extends RefCounted

var time=99.0
var power=0.0
var value=0.0
var direction=Vector3(-.5,.5,-.7).normalized()
var rng=preload("res://scripts/fx_random.gd").new()
var material:ShaderMaterial

func _init(sky_material:ShaderMaterial=null,random_stream=null)->void:
 material=sky_material
 if random_stream!=null:rng=random_stream

# Original render thunder callback consumes three Math.random values.
func trigger(intensity:float=.6,random_values:Vector3=Vector3(-1,-1,-1))->void:
 time=0;power=minf(1,intensity if intensity!=0 else .6)
 var draws=[random_values.x,random_values.y,random_values.z] if random_values.x>=0 else [rng.randf(),rng.randf(),rng.randf()]
 var angle=PI*(.55+draws[0]*.9)
 var x=cos(angle);var y=.35+draws[1]*.3;var z=sin(angle)*(-1 if draws[2]<.5 else 1);var inverse=1.0/sqrt(x*x+y*y+z*z)
 direction=Vector3(x*inverse,y*inverse,z*inverse)
 if material!=null:material.set_shader_parameter("uFlashDir",direction)

func update(dt:float,world_time:float)->void:
 time+=dt
 value=power*exp(-time*5)*(.55+.45*sin(time*47)*sin(time*13+1))*.35 if time<.9 else 0.0
 if material!=null:
  material.set_shader_parameter("uTime",world_time);material.set_shader_parameter("uFlash",maxf(0,value))
