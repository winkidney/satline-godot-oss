extends SceneTree
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/smolder-reference.json"))
 var tape=[]
 for encoded in data.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var mapping={"life":"life","s0":"s0","s1":"s1","seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","mode":"mode","flags":"flags","ramp":"ramp","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk","stretch":"stretch","gy":"floor"}
 for test in data.cases:
  var fx=SaltlineImpactEffects.new();fx.rng=rng;fx.lit_pool=SaltlineParticles.new(int(test.capacity),true,rng)
  var explosion=SaltlineExplosionEffects.new(fx,null,null,rng)
  for i in test.rows.size():
   var row=test.rows[i];var op=row.op;var expected=row.expected;var result:Variant=null;var context="%s/%s"%[test.capacity,i]
   if op.kind=="start":
    var ttl=INF if op.ttl is String else float(op.ttl)
    var handle=explosion._start_smolder(Vector3(op.position[0],op.position[1],op.position[2]),ttl,float(op.scale),float(op.shade));result=explosion.emitter_slots.find(handle)
   elif op.kind=="update":explosion.update(float(op.dt))
   elif op.kind=="clear_particles":fx.lit_pool.clear()
   else:explosion.clear();fx.lit_pool.clear()
   checks+=1
   if result!=expected.result:failures.append({"step":context,"handle":result,"expected":expected.result})
   compare(rng.calls,expected.calls,context+"/calls",0)
   var active=0
   for j in 24:
    var actual=explosion.emitter_slots[j];var e=expected.slots[j]
    compare(int(actual.active),int(e.active),context+"/slot",0)
    if not e.active or not actual.active:continue
    active+=1
    for key in ["time","scale","shade","accumulator"]:compare(actual[key],e[key],context+"/"+key,1e-10)
    if e.ttl is String:
     checks+=1
     if not is_inf(float(actual.ttl)):failures.append({"step":context,"ttl":"expected INF"})
    else:compare(actual.ttl,e.ttl,context+"/ttl",1e-10)
    for k in 3:compare(actual.position[k],e.position[k],context+"/position",.000003)
   compare(explosion.emitters.size(),active,context+"/active getter",0)
   var actual=fx.lit_pool.particles;var expected_particles=expected.particles
   compare(actual.size(),expected_particles.size(),context+"/particle count",0)
   for j in mini(actual.size(),expected_particles.size()):
    var particle=actual[j];var e=expected_particles[j]
    for key in mapping:compare(particle[mapping[key]],e[key],context+"/particle/"+key,.000003)
    for k in 3:
     compare(particle.position[k],e[["px","py","pz"][k]],context+"/particle position",.000003)
     compare(particle.velocity[k],e[["vx","vy","vz"][k]],context+"/particle velocity",.000003)
     compare(particle.color[k],e[["r","g","b"][k]],context+"/particle color",.000003)
  fx.free()
 var report={"cases":data.cases.size(),"steps_per_case":data.cases[0].rows.size(),"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":data.source_sha256,"methods_sha256":data.methods_sha256,"scope":"Original G/oe/M/u1 smolder path, fixed24 slots, overflow, expiry/strict ttl, reuse, strict accumulator>1, INF, clear, negative-dt sanitation and pool2/256 saturation. Particle generation states only, no motion/pixel or other emitter kinds."}
 FileAccess.open("res://evidence/smolder-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
