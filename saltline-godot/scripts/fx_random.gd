extends RefCounted
# Source Math.random namespace: independent of su forks, shared by runtime FX.
# A supplied double tape makes original/native call order directly comparable.
var tape_mode=false
var tape:Array=[]
var calls=0
var exhausted=false
var valid_tape=true
func _init(values:Variant=null)->void:
 if values!=null:
  tape_mode=true
  if not values is Array:
   valid_tape=false;push_error("FX random tape must be an Array");return
  tape=values.duplicate()
  for value in tape:
   if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>=1:
    valid_tape=false;push_error("Invalid FX random tape sample");return
func randf()->float:
 if not valid_tape:return NAN
 var value:float
 if tape_mode:
  if calls>=tape.size():
   exhausted=true;push_error("FX random tape exhausted at draw "+str(calls));return NAN
  value=float(tape[calls])
 else:
  # Uniform 53-bit [0,1), independent of deterministic source su streams.
  var high=int(randi())>>5;var low=int(randi())>>6
  value=(float(high)*67108864.0+float(low))/9007199254740992.0
 calls+=1
 return value
func randf_range(minimum:float,maximum:float)->float:return minimum+(maximum-minimum)*self.randf()
func randi_range(minimum:int,maximum:int)->int:return minimum+int(floor((maximum-minimum+1)*self.randf()))
