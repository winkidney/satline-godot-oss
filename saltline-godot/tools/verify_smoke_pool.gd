extends SceneTree
class Probe:
 extends SaltlineImpactEffects
 func shade_at(_position:Vector3,_normal:Vector3)->float:return .2
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/smoke-pool-reference.json"))
 var rng=preload("res://scripts/fx_random.gd").new(data.tape)
 var mapping={"life":"life","s0":"s0","s1":"s1","seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","mode":"mode","flags":"flags","ramp":"ramp","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk","stretch":"stretch","gy":"floor"}
 for test in data.cases:
  var fx=Probe.new();fx.rng=rng;fx.lit_pool=SaltlineParticles.new(int(test.capacity),true,rng)
  for i in test.rows.size():
   var row=test.rows[i];var options=row.options.duplicate(true);var context="%s/%s"%[test.capacity,i]
   if row.clear:fx.lit_pool.clear()
   if options.has("vel"):options.vel=Vector3(options.vel[0],options.vel[1],options.vel[2])
   fx.smoke(Vector3(1,2,3),options)
   compare(rng.calls,row.calls,context+"/calls",0)
   compare(fx.lit_pool.particles.size(),row.particles.size(),context+"/count",0)
   for j in mini(fx.lit_pool.particles.size(),row.particles.size()):
    var p=fx.lit_pool.particles[j];var e=row.particles[j]
    for key in mapping:compare(p[mapping[key]],e[key],context+"/"+key,.000001)
    for k in 3:
     compare(p.position[k],e[["px","py","pz"][k]],context+"/position",.000001)
     compare(p.velocity[k],e[["vx","vy","vz"][k]],context+"/velocity",.000001)
     compare(p.color[k],e[["r","g","b"][k]],context+"/color",.000001)
  fx.free()
 var report={"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":data.source_sha256,"scope":"Literal I/ph/M/u1 smoke generation, real native particle pool, 2/64 saturation, clear/reuse; no particle motion or render."}
 FileAccess.open("res://evidence/smoke-pool-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
