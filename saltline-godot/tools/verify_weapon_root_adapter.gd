extends SceneTree
class PhysicsStub extends SaltlinePhysics:
 var row:Dictionary
 var queries=0
 var bad_arguments=0
 func _init()->void:super({"boxes":[],"bounds":{}})
 func raycast(_origin:Vector3,_direction:Vector3,_distance:float)->Dictionary:
  queries+=1
  if _origin!=Vector3(row.player.eye[0],row.player.eye[1],row.player.eye[2]) or _direction!=Vector3(0,0,-1) or _distance!=row.ray_far:bad_arguments+=1
  return {} if row.hit==null else {"dist":row.hit}
var failures=[]
var maximum_state=0.0
var maximum_matrix=0.0
var context=""
func fail(message:String)->void:
 if failures.size()<20:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is bool or expected==null:
  if actual!=expected:fail(path+" mismatch")
 else:
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum_state=maxf(maximum_state,error)
  if error>1e-8:fail(path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-root-adapter-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var steps=0
 for sample in reference.cases:
  var physics=PhysicsStub.new();var player=load("res://scripts/player.gd").new(data.modules.player,physics);var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon);weapon.current=sample.gun
  weapon.motion_state.clear();weapon.motion_state.merge(sample.initial.duplicate(true),true)
  var random_index=[0];var values=[.07,.91,.32,.68,.5]
  weapon.root_motion.random_source=func():
   var value=values[random_index[0]%5];random_index[0]+=1;return value
  for index in sample.steps.size():
   context=sample.gun+"/"+str(index);var row=sample.steps[index].input;var expected=sample.steps[index].expected
   physics.row=row;player.on_ground=row.player.onGround;player.speed=row.player.speed;player.velocity=Vector3(row.player.vel.x,row.player.vel.y,row.player.vel.z);player.yaw=row.player.yaw;player.eye=Vector3(row.player.eye[0],row.player.eye[1],row.player.eye[2]);player.forward=Vector3(0,0,-1);player.crouching=row.player.crouching;player.sprinting=row.player.sprinting;player.tuning=row.player.tuning
   weapon.motion_state.merge(row.patch.duplicate(true),true)
   for key in row.impulses:weapon.motion_state[key].v+=row.impulses[key]
   weapon.motion_state.t+=row.dt;weapon.root_motion.no_idle=row.no_idle;weapon.motion_inspect=row.inspect
   var camera=[];var shakes=[]
   if row.fire:
    var callback=func(pitch,yaw):camera.append([pitch,yaw])
    var shake_callback=func(value):shakes.append(value)
    weapon.root_motion.recoil(sample.gun,weapon.rigs[sample.gun],row.burst,row.camera_scale,player.crouching,callback if row.camera_enabled else Callable(),shake_callback if row.camera_enabled else Callable())
   var result=weapon.step_root(row.dt,row.input,player)
   compare(weapon.motion_state,expected.state,"S")
   if random_index[0]!=expected.random_calls or physics.queries!=expected.wall_queries or physics.bad_arguments!=0:fail("RNG/raycast count")
   var matrix=[result.basis.x.x,result.basis.x.y,result.basis.x.z,0,result.basis.y.x,result.basis.y.y,result.basis.y.z,0,result.basis.z.x,result.basis.z.y,result.basis.z.z,0,result.origin.x,result.origin.y,result.origin.z,1]
   for channel in 16:
    if not is_finite(float(matrix[channel])):fail("non-finite matrix");continue
    var error=absf(matrix[channel]-expected.matrix[channel]);maximum_matrix=maxf(maximum_matrix,error)
    if error>2e-6:fail("matrix error="+str(error))
   steps+=1
  if weapon.live_root_steps!=sample.steps.size():fail("adapter step count")
 var report={"steps":steps,"maximum_state_error":maximum_state,"maximum_matrix_error":maximum_matrix,"failures":failures,"scope":"Production Weapon.step_root adapter vs literal original D, inputs quantized to Native Player Vector3 before original evaluation; exact null/empty ray bridge and same shared S/RNG. Explicit external inputs, no whole O/Main or arm/IK proof."}
 FileAccess.open("res://evidence/weapon-root-adapter-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
