extends SceneTree
const Motion=preload("res://scripts/weapon_root_motion.gd")
var failures=[]
var maximum_state=0.0
var maximum_transform=0.0
var scalar_comparisons=0
var context=""
func fail(message:String)->void:
 if failures.size()<24:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is Array:
  if actual.size()!=expected.size():fail(path+" array size");return
  for index in expected.size():compare(actual[index],expected[index],path+"/"+str(index))
 elif expected is bool or expected==null:
  if actual!=expected:fail(path+" value mismatch")
 elif expected is int or expected is float:
  if not is_finite(float(actual)) or not is_finite(float(expected)):
   fail(path+" non-finite scalar");return
  var error=absf(float(actual)-float(expected));maximum_state=maxf(maximum_state,error);scalar_comparisons+=1
  if error>1e-8:fail(path+" error="+str(error))
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-root-motion-reference.json"))
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var steps=0
 for sample in reference.cases:
  var random_index=[0];var random_values=[.07,.91,.32,.68,.5];var current_row=[{}];var ray_count=[0]
  var random=func():
   var value=random_values[random_index[0]%random_values.size()];random_index[0]+=1;return value
  var ray=func(eye,forward,far):
   ray_count[0]+=1
   if eye!=current_row[0].player.eye or forward!=current_row[0].player.forward or far!=data.modules.weapon.rigs[sample.gun].motion.wall.far:fail("ray arguments")
   return null if current_row[0].hit==null else {"dist":current_row[0].hit}
  var motion=Motion.new(sample.initial,random)
  for index in sample.steps.size():
   context=sample.gun+"/"+str(index)
   var row:Dictionary=sample.steps[index].input;var expected:Dictionary=sample.steps[index].expected;current_row[0]=row
   motion.a.merge(row.patch.duplicate(true),true)
   for key in row.impulses:motion.a[key].v+=row.impulses[key]
   motion.a.t+=row.dt;motion.no_idle=row.no_idle
   var camera=[];var shakes=[]
   if row.fire:
    var camera_callback=func(pitch,yaw):camera.append([pitch,yaw])
    var shake_callback=func(value):shakes.append(value)
    motion.recoil(sample.gun,data.modules.weapon.rigs[sample.gun],row.burst,row.camera_scale,row.player.crouching,camera_callback if row.camera_enabled else Callable(),shake_callback if row.camera_enabled else Callable())
   compare(camera,expected.camera,"camera");compare(shakes,expected.shakes,"shake")
   var result:Transform3D=motion.step(row.dt,data.modules.weapon.rigs[sample.gun],row.player,row.input,row.inspect,Callable() if row.no_raycast else ray)
   compare(motion.a,expected.state,"state")
   if motion.random_calls!=expected.random_calls or random_index[0]!=expected.random_calls:fail("RNG count")
   if motion.wall_queries!=expected.wall_queries or ray_count[0]!=expected.wall_queries:fail("wall query count")
   var values=[result.basis.x.x,result.basis.x.y,result.basis.x.z,0,result.basis.y.x,result.basis.y.y,result.basis.y.z,0,result.basis.z.x,result.basis.z.y,result.basis.z.z,0,result.origin.x,result.origin.y,result.origin.z,1]
   for channel in 16:
    if not is_finite(values[channel]) or not is_finite(float(expected.matrix[channel])):fail("non-finite matrix");continue
    var error=absf(values[channel]-expected.matrix[channel]);maximum_transform=maxf(maximum_transform,error)
    if error>2e-6:fail("matrix/"+str(channel)+" error="+str(error))
   steps+=1
 var report={"steps":steps,"cases":reference.cases.size(),"scalar_comparisons":scalar_comparisons,"maximum_state_error":maximum_state,"maximum_matrix_error":maximum_transform,"state_tolerance":1e-8,"matrix_tolerance":2e-6,"failures":failures,"reference_source_sha256":reference.source_sha256,"reference_D_sha256":reference.D_sha256,"reference_recoil_sha256":reference.recoil_sha256,"scope":reference.scope+" Native scalar history/springs and float32 final Transform3D, per-step wall/RNG consumption. No production root/recoil/reload/IK cutover proof."}
 FileAccess.open("res://evidence/weapon-root-motion-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
