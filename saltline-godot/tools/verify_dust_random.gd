extends SceneTree
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/dust-random-reference.json"))
 var tape=[]
 for encoded in data.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var fx=preload("res://scripts/impact_effects.gd").new();fx.rng=rng
 fx.physics=SaltlinePhysics.new({"boxes":[],"bounds":{}})
 var map={"life":"life","s0":"s0","s1":"s1","seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","mode":"mode","flags":"flags","ramp":"ramp","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk","stretch":"stretch","gy":"floor"}
 for test in data.cases:
  fx.pool=SaltlineParticles.new(int(test.capacity),false,rng);fx.lit_pool=SaltlineParticles.new(int(test.capacity),true,rng)
  for i in test.rows.size():
   if i==2:fx.pool.clear();fx.lit_pool.clear()
   fx.dust(Vector3(3,-1.6,2),Vector3.UP,float(test.size),Vector3(.5,.48,.45))
   var row=test.rows[i];compare(rng.calls,row.calls,"calls/%s/%s/%s"%[test.capacity,test.size,i],0)
   for kind in ["add","lit"]:
    var actual=fx.pool.particles if kind=="add" else fx.lit_pool.particles
    var expected=row.pools[kind]
    compare(actual.size(),expected.size(),"count",0)
    for j in mini(actual.size(),expected.size()):
     var p=actual[j];var e=expected[j]
     for k in map:compare(p[map[k]],e[k],"%s/%s/%s/%s/%s"%[test.capacity,test.size,i,j,k],.000002)
     for k in 3:
      compare(p.position[k],e[["px","py","pz"][k]],"position",.000002)
      compare(p.velocity[k],e[["vx","vy","vz"][k]],"velocity",.000002)
      compare(p.color[k],e[["r","g","b"][k]],"color",.000002)
 var report={"cases":data.cases.size(),"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":data.source_sha256,"methods_sha256":data.methods_sha256,"scope":"Original go/M/L/u1, emission state only; 3 sizes, 7 capacities, repeat saturation then clear; same tape across cases. No motion/pixel proof."}
 var f=FileAccess.open("res://evidence/dust-random-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));fx.free();quit(0 if failures.is_empty() else 1)
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
