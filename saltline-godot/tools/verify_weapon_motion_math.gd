extends SceneTree
const MotionMath=preload("res://scripts/weapon_motion_math.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-motion-math-reference.json"));var failures=[];var maximum_position=0.0;var maximum_velocity=0.0;var maximum_noise=0.0;var steps=0
 for index in reference.cases.size():
  var sample=reference.cases[index];var state=sample.initial.duplicate(true)
  for row in sample.steps:
   state.v+=row.impulse
   if row.reset!=null:MotionMath.reset(state,row.reset)
   MotionMath.advance(state,row.target,row.dt,row.frequency,row.damping);var position_error=absf(state.x-row.x);var velocity_error=absf(state.v-row.v);maximum_position=maxf(maximum_position,position_error);maximum_velocity=maxf(maximum_velocity,velocity_error);steps+=1
   if (position_error>1e-10 or velocity_error>1e-9) and failures.size()<20:failures.append({"case":index,"step":steps,"position_error":position_error,"velocity_error":velocity_error})
 for sample in reference.noises:
  var delta=maxf(absf(MotionMath.hash_noise(sample.x)-sample.hash),maxf(absf(MotionMath.noise(sample.x,sample.seed)-sample.noise),absf(MotionMath.soft_limit(sample.x,.07)-sample.soft)));maximum_noise=maxf(maximum_noise,delta)
  if delta>3e-8 and failures.size()<20:failures.append({"noise_x":sample.x,"error":delta})
 var report={"trajectories":reference.cases.size(),"steps":steps,"noise_cases":reference.noises.size(),"maximum_position_error":maximum_position,"maximum_velocity_error":maximum_velocity,"maximum_noise_error":maximum_noise,"failures":failures,"scope":"Native CPU double math vs literaloriginal JS,criticalthreshold/overrides/impulses/resets;position1e-10 velocity1e-9 noise3e-8; observed libm/JS sine hash difference bounded separately. No full rootmotion/IK or gameplay integration proof."};FileAccess.open("res://evidence/weapon-motion-math-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
