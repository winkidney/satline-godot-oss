extends SceneTree
var failures=[]
var checks=0
var maximum=0.0
func compare(a,b,path:String)->void:
 if a is Vector3:a=[a.x,a.y,a.z]
 if b is Dictionary:
  for key in b:compare(a[key],b[key],path+"/"+key)
 elif b is Array:
  if a.size()!=b.size():failures.append(path+" size");return
  for j in b.size():compare(a[j],b[j],path+"/"+str(j))
 elif b==null or b is bool:
  checks+=1
  if a!=b:failures.append(path)
 else:
  checks+=1;var error=absf(float(a)-float(b));maximum=maxf(maximum,error)
  var tolerance=1e-7 if path.contains("sky/direction") else 1e-10
  if (not is_finite(float(a)) or not is_finite(float(b)) or error>tolerance) and failures.size()<20:failures.append({"path":path,"actual":a,"expected":b,"error":error})
func _initialize()->void:
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/fx-random-reference.json"))
 var values=[]
 for bits in ref.tape_u53:values.append(float(bits.hex_to_int())/9007199254740992.0)
 var random=preload("res://scripts/fx_random.gd").new(values)
 var pools={"a":SaltlineParticles.new(2,false,random),"b":SaltlineParticles.new(3,true,random)}
 var sky=SaltlineSkyWeather.new(null,random);var steps=0
 for row in ref.rows:
  var input=row.input;var result=null
  if input.kind.begins_with("emit"):
   var p=input.position;var v=input.velocity;var options=input.options.duplicate(true)
   if options.has("color"):var c=options.color;options.color=Vector3(c[0],c[1],c[2])
   result=not pools[input.pool].emit(Vector3(p[0],p[1],p[2]),Vector3(v[0],v[1],v[2]),input.life,input.s0,input.s1,options).is_empty()
  elif input.kind=="sky":sky.trigger(input.intensity)
  elif input.kind=="range":result=random.randf_range(-2,3)
  elif input.kind=="integer":result=random.randi_range(0,1)
  elif input.kind=="clearA":pools.a.clear()
  else:pools.b.clear()
  compare({"result":result,"calls":random.calls,"pools":{"a":pools.a.particles,"b":pools.b.particles},"sky":{"time":sky.time,"power":sky.power,"direction":sky.direction}},row.expected,str(steps))
  steps+=1
 var upper=ref.nonzero_integer_upper
 var edge=preload("res://scripts/fx_random.gd").new([float(upper.u53.hex_to_int())/9007199254740992.0])
 checks+=1
 if edge.randi_range(int(upper.minimum),int(upper.maximum))!=int(upper.expected):failures.append("nonzero integer bound rounded out of range")
 var entropy=preload("res://scripts/fx_random.gd").new()
 for j in 4096:
  var value=entropy.randf();checks+=1
  if not is_finite(value) or value<0 or value>=1:failures.append("entropy range")
 checks+=1
 if random.exhausted or random.calls!=183:failures.append("shared tape draw count")
 var report={"steps":steps,"draws":random.calls,"checks":checks,"maximum_error":maximum,"tolerance":{"scalar":1e-10,"sky_direction":1e-7},"failures":failures,"source_sha256":ref.source_sha256,"methods_sha256":ref.methods_sha256,"scope":ref.scope+" Native shared service, actual particle and sky APIs; 4096 entropy samples checked finite [0,1), not statistical/browser entropy equivalence."}
 FileAccess.open("res://evidence/fx-random-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
