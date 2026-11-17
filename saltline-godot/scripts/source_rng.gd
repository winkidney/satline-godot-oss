class_name SaltlineSourceRng
extends RefCounted

const MASK=0xffffffff
var state:int=0
var calls:int=0
var seed:int=1337:
 set(value):
  seed=value;state=value&MASK;calls=0

func _init(initial_seed:int=1337)->void:
 seed=initial_seed

func _imul(a:int,b:int)->int:
 var low=(a&65535)*(b&65535)
 var cross_term=(a>>16)*(b&65535)+(a&65535)*(b>>16)
 return (low+(cross_term<<16))&MASK

func randf()->float:
 calls+=1
 state=(state+1831565813)&MASK
 var value=_imul(state^(state>>15),1|state)
 value=((value+_imul(value^(value>>7),61|value))^value)&MASK
 return float((value^(value>>14))&MASK)/4294967296.0

func randf_range(minimum:float,maximum:float)->float:
 return minimum+(maximum-minimum)*self.randf()

func randi_range(minimum:int,maximum:int)->int:
 return int(floor(minimum+(maximum-minimum+1)*self.randf()))

func pick(values:Array)->Variant:
 return values[int(floor(self.randf()*values.size()))]

func random_sign()->int:
 return -1 if self.randf()<.5 else 1

func fork()->SaltlineSourceRng:
 return SaltlineSourceRng.new(int(floor(self.randf()*4294967296.0)))
