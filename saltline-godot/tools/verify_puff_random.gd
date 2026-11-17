extends SceneTree

func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/puff-random-reference.json"))
 var tape=[]
 for encoded in data.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var fx=preload("res://scripts/impact_effects.gd").new()
 fx.rng=rng;fx.lit_pool=SaltlineParticles.new(3,true,rng)
 var mapping={"seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk"}
 var failures=[];var checks=0;var max_error=0.0
 for i in data.rows.size():
  if i==6 or i==13:fx.lit_pool.clear()
  var row=data.rows[i]
  var p=fx.puff(Vector3(.1,.2,.3),Vector3(.4,.5,.6),.7,.8,.9,Vector3(.11,.22,.33),.44,.55,.66,.77,.88,int(row.frame))
  checks+=1
  if rng.calls!=int(row.calls):failures.append({"step":i,"calls":rng.calls,"expected":row.calls})
  checks+=1
  if p.is_empty()!=(row.result==null):failures.append({"step":i,"presence":false})
  if p.is_empty() or row.result==null:continue
  for source in mapping:
   var error=abs(float(p[mapping[source]])-float(row.result[source]));max_error=maxf(max_error,error);checks+=1
   if not is_finite(error) or error>1e-7:failures.append({"step":i,"field":source,"error":error})
  for k in 3:
   var error=abs(float(p.color[k])-float(row.result[["r","g","b"][k]]));max_error=maxf(max_error,error);checks+=1
   if not is_finite(error) or error>1e-7:failures.append({"step":i,"color":k,"error":error})
 var report={"steps":data.rows.size(),"checks":checks,"draws":rng.calls,"maximum_error":max_error,"failures":failures,"scope":data.scope,"source_sha256":data.source_sha256,"methods_sha256":data.methods_sha256}
 var f=FileAccess.open("res://evidence/puff-random-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));fx.free();quit(0 if failures.is_empty() else 1)
