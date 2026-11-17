extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
var draws=0
var traces={}
var row_input={}
func compare(actual,expected,context:String)->void:
 if expected is Dictionary:
  for key in expected:compare(actual[key],expected[key],context+"/"+key)
 elif expected is Array:
  if actual.size()!=expected.size():failures.append({"context":context,"actual_count":actual.size(),"expected_count":expected.size()});return
  for j in expected.size():compare(actual[j],expected[j],context+"/"+str(j))
 elif expected is bool or expected is String:
  checks+=1
  if actual!=expected:failures.append({"context":context,"actual":actual,"expected":expected})
 else:
  checks+=1;var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if (not is_finite(float(actual)) or not is_finite(float(expected)) or error>1e-10) and failures.size()<25:failures.append({"context":context,"actual":actual,"expected":expected,"error":error})
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-drop-reference.json"));var steps=0
 for case in reference.cases:
  var rng=preload("res://scripts/source_rng.gd").new(4207);draws=0
  var random=func():draws+=1;return rng.randf()
  var module=load("res://scripts/weapon_drop_motion.gd").new(random)
  module.splash=func(p,size):traces.splashes.append([p,size])
  var ray=func(p,d,distance):traces.rays.append([p,d,distance]);return {} if row_input.wall else null
  var ground=func(x,z,y):traces.ground.append([x,z,y]);return row_input.floor
  var arm_start=func(random_source):
   for j in 6:random_source.call()
  for row in case.rows:
   row_input=row.input;var input=row_input;traces={"rays":[],"ground":[],"splashes":[]}
   if input.restore:module.restore()
   if input.start:module.start(input.gun,input.local_p,input.local_q,input.camera_p,input.camera_q,input.camera_fov,input.view_fov,input.player_velocity,arm_start)
   module.step(input.dt,ray,ground)
   var actual={"active":module.active,"gun":module.gun,"time":module.time,"position":module.position,"rotation":module.rotation,"velocity":module.velocity,"angular":module.angular,"resting":module.resting,"sunk":module.sunk,"visible":module.visible,"bounces":module.bounces,"heard":module.heard,"rest_time":module.rest_time,"rest_rotation":module.rest_rotation,"random_state":rng.state,"random_calls":draws,"traces":traces}
   compare(actual,row.expected,case.mode+"/"+str(steps));steps+=1
 var report={"steps":steps,"checks":checks,"maximum_error":maximum,"tolerance":1e-10,"failures":failures,"source_sha256":reference.source_sha256,"drop_sha256":reference.drop_sha256,"scope":reference.scope+" Native double numeric stage and all physics/splash query arguments plus shared RNG state/count. Six arm-start RNG draws explicit adapter; arm trajectory separately pending."}
 FileAccess.open("res://evidence/weapon-drop-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
