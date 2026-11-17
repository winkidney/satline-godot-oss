extends SceneTree
class Recorder extends "res://scripts/tracers.gd":
 func _draw(quads:Array)->void:draw_records=quads;quads_drawn=quads.size()
class Effects extends SaltlineImpactEffects:
 func shade_at(_position:Vector3,_normal:Vector3)->float:return 1
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/tracer-trail-reference.json"));var tape=[]
 for encoded in fixture.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var pmap={"life":"life","s0":"s0","s1":"s1","seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","mode":"mode","flags":"flags","ramp":"ramp","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk","stretch":"stretch","gy":"floor"}
 var tmap={"dist":"distance","speed":"speed","trav":"travel","len":"length","width":"width","frames":"frames"}
 for test in fixture.cases:
  var tracer=Recorder.new();tracer.rng=rng;var fx=Effects.new();fx.rng=rng;fx.lit_pool=SaltlineParticles.new(int(test.capacity),true,rng);fx.tracer_pool=tracer
  for step in test.rows.size():
   var row=test.rows[step];var op=row.op;var context="%s/%s"%[test.capacity,step]
   if op.has("time"):fx.clock=float(op.time)
   if op.kind=="emit":fx.tracer(vec(op.origin),vec(op.end),op.get("options",{}))
   elif op.kind=="update":fx.clock+=float(op.dt);tracer.update(float(op.dt))
   else:tracer.clear();fx.lit_pool.clear()
   var e=row.expected;compare(rng.calls,e.calls,context+"/calls",0);compare(fx.clock,e.time,context+"/time",1e-10);compare(fx.tracer_trail_time,e.last_time,context+"/trail timer",1e-10)
   compare(tracer.shots.size(),e.tracers.size(),context+"/tracer count",0)
   for i in mini(tracer.shots.size(),e.tracers.size()):
    var actual=tracer.shots[i];var expected=e.tracers[i]
    for key in tmap:compare(actual[tmap[key]],expected[key],context+"/tracer/"+key,.000001)
    for k in 3:
     compare(actual.origin[k],expected[["fx","fy","fz"][k]],context+"/tracer origin",.000001)
     compare(actual.direction[k],expected[["dx","dy","dz"][k]],context+"/tracer direction",.000001)
     compare(actual.color[k],expected[["r","g","b"][k]],context+"/tracer color",.000001)
   compare(fx.lit_pool.particles.size(),e.particles.size(),context+"/particle count",0)
   for i in mini(fx.lit_pool.particles.size(),e.particles.size()):
    var actual=fx.lit_pool.particles[i];var expected=e.particles[i]
    for key in pmap:compare(actual[pmap[key]],expected[key],context+"/particle/"+key,.000001)
    for k in 3:
     compare(actual.position[k],expected[["px","py","pz"][k]],context+"/particle position",.000001)
     compare(actual.velocity[k],expected[["vx","vy","vz"][k]],context+"/particle velocity",.000001)
     compare(actual.color[k],expected[["r","g","b"][k]],context+"/particle color",.000001)
   compare(tracer.draw_records.size(),e.quads.size(),context+"/quad count",0)
   for i in mini(tracer.draw_records.size(),e.quads.size()):
    var q=tracer.draw_records[i];var actual=PackedFloat32Array([q[0].x,q[0].y,q[0].z,q[1],q[2].x,q[2].y,q[2].z,0,q[3].x,q[3].y,q[3].z,1,q[4],q[5],0,q[6]])
    for k in actual.size():compare(actual[k],e.quads[i][k],context+"/quad/"+str(k),.000001)
  fx.free();tracer.free()
 var report={"cases":fixture.cases.size(),"steps_per_case":fixture.cases[0].rows.size(),"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":fixture.scope}
 FileAccess.open("res://evidence/tracer-trail-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func vec(values:Array)->Vector3:return Vector3(values[0],values[1],values[2])
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
