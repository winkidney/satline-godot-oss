extends SceneTree
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/navigation-random-reference.json"))
 var random=preload("res://scripts/fx_random.gd").new(reference.tape);var physics=SaltlinePhysics.new(data.physics);var nav=SaltlineNavigation.new(physics,random)
 var effects=SaltlineImpactEffects.new();effects.rng=random;effects.physics=physics;effects.lit_pool=SaltlineParticles.new(1400,true,random)
 var failures=[];var maximum=0.0;var checks=0
 nav.rebuild();nav.find_path(Vector3(-32,0,6),Vector3(1.5,0,7.5))
 if random.calls!=0:failures.append("construct/build/path consumed source Math.random")
 for row in reference.rows:
  var input=row.input;var result:Variant=null
  if input.kind=="point":
   var origin=Vector3(input.origin[0],input.origin[1],input.origin[2]);result=nav.random_point(origin,float(input.radius))
   var expected=Vector3(row.result[0],row.result[1],row.result[2]);var error=result.distance_to(expected);maximum=maxf(maximum,error)
   if error>.00001:failures.append({"input":input,"actual":str(result),"expected":str(expected),"error":error})
  elif input.kind=="smoke":effects.smoke(Vector3(-32,1,6),{"count":1,"size":.5,"life":1,"color":0x202020})
  else:
   result=random.randf()
   if absf(float(result)-float(row.result))>.0000000001:failures.append("interleaved Math.random value")
  checks+=1
  if random.calls!=int(row.calls):failures.append({"input":input,"calls":random.calls,"expected":row.calls})
 if random.exhausted or random.calls!=int(reference.calls):failures.append("shared random tape consumption")
 var report={"checks":checks,"draws":random.calls,"smoke_particles":effects.lit_pool.particles.size(),"maximum_point_error":maximum,"failures":failures,"navigation_sha256":FileAccess.get_sha256("res://scripts/navigation.gd"),"scope":reference.scope+" Native actual Navigation/ImpactEffects/Particles share one tape, including24-attempt fallback; normal grid/path construction consumes no random values. Default browser entropy values are not reproducible."}
 FileAccess.open("res://evidence/navigation-random-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));effects.free();quit(0 if failures.is_empty() else 1)
