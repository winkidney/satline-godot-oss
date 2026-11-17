extends SceneTree
class Effects extends SaltlineImpactEffects:
 var controlled_shade=1.0
 func shade_at(_p:Vector3,_n:Vector3)->float:return controlled_shade
 func ground_at(_p:Vector3)->float:return -50
class Lights extends SaltlineLightPool:
 var requests=[]
 func flash(position:Vector3,color:int=0xffc880,energy:float=30,radius:float=10,duration:float=.06)->void:requests.append({"position":[position.x,position.y,position.z],"args":[color,energy,radius,duration]})
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 call_deferred("verify")
func verify()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/impact-random-reference.json"))
 var tape=[]
 for encoded in data.tape_u53:tape.append(float(String(encoded).hex_to_int())/9007199254740992.0)
 var rng=preload("res://scripts/fx_random.gd").new(tape)
 var camera=Camera3D.new();root.add_child(camera)
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[{"name":"fx_debris","id":"test"}]}
 var instance=MultiMeshInstance3D.new();instance.multimesh=MultiMesh.new();instance.multimesh.transform_format=MultiMesh.TRANSFORM_3D;instance.multimesh.use_custom_data=true;instance.multimesh.mesh=BoxMesh.new();instance.multimesh.instance_count=256;scene.source_nodes={"test":instance}
 var map={"life":"life","s0":"s0","s1":"s1","seed":"seed","rot":"rotation","rotv":"rotation_speed","frame":"frame","mode":"mode","flags":"flags","ramp":"ramp","a":"alpha","shade":"shade","drag":"drag","grav":"gravity","wind":"wind","turb":"turbulence","fin":"fade_in","fout":"fade_out","sk":"sk","stretch":"stretch","gy":"floor"}
 for test in data.cases:
  var fx=Effects.new();fx.controlled_shade=float(test.shade);fx.rng=rng;fx.camera=camera;fx.pool=SaltlineParticles.new(int(test.capacity),false,rng);fx.lit_pool=SaltlineParticles.new(int(test.capacity),true,rng);fx.debris=SaltlineDebris.new(scene,rng)
  var lights=Lights.new();fx.light_pool=lights;camera.position=Vector3(100 if test.far else 0,0,0)
  for row in test.rows:
   fx.clock=float(row.time);fx.impact({"point":Vector3(3,1,2),"normal":Vector3(row.normal[0],row.normal[1],row.normal[2]),"surface":row.surface},Vector3(row.direction[0],row.direction[1],row.direction[2]))
   var context="%s/%s/%s/%s"%[test.surface,test.capacity,test.far,row.time]
   compare(rng.calls,row.calls,context+"/calls",0)
   for kind in ["add","lit"]:
    var actual=fx.pool.particles if kind=="add" else fx.lit_pool.particles;var expected=row.pools[kind]
    compare(actual.size(),expected.size(),context+"/count",0)
    for j in mini(actual.size(),expected.size()):
     var p=actual[j];var e=expected[j]
     for k in map:compare(p[map[k]],e[k],context+"/"+k,.000003)
     for k in 3:
      compare(p.position[k],e[["px","py","pz"][k]],context+"/position",.000003)
      compare(p.velocity[k],e[["vx","vy","vz"][k]],context+"/velocity",.000003)
      compare(p.color[k],e[["r","g","b"][k]],context+"/color",.000003)
   compare(fx.debris.next,row.debris.size(),context+"/debris count",0)
   for j in mini(fx.debris.next,row.debris.size()):
    var p=fx.debris.slots[j];var e=row.debris[j]
    for pair in [["ang","angle"],["spin","spin"],["age","age"],["life","life"],["floor","floor"],["state","state"]]:compare(p[pair[1]],e[pair[0]],context+"/debris/"+pair[0],.000003)
    var color:Vector3=p.color
    for k in 3:compare(color[k],e[["r","g","b"][k]],context+"/debris/color",.000003)
    for key in ["position","velocity","axis","size"]:
     var names={"position":["px","py","pz"],"velocity":["vx","vy","vz"],"axis":["ax","ay","az"],"size":["sx","sy","sz"]}[key]
     for k in 3:compare(p[key][k],e[names[k]],context+"/debris/"+key,.000003)
   compare(lights.requests.size(),row.lights.size(),context+"/lights",0)
   for j in mini(lights.requests.size(),row.lights.size()):
    for key in ["position","args"]:
     for k in row.lights[j][key].size():compare(lights.requests[j][key][k],row.lights[j][key][k],context+"/light/"+key,.000003)
  fx.free();lights.free()
 var report={"cases":data.cases.size(),"checks":checks,"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":data.source_sha256,"methods_sha256":data.methods_sha256,"scope":"Original A and helpers plus literal jg.add; 8 materials, near/far, 2/80 capacity, 6 clock samples including strict .09 threshold. Actual native debris, particles and light requests. Cross-metal/enemy light throttle, zero/tiny normal and direction fallbacks, debris CPU RGB driving custom-data writes; controlled shade1/.2, no decal random consumer, puddle, actual shadow query, motion or pixel proof."}
 var f=FileAccess.open("res://evidence/impact-random-verification.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close();print(JSON.stringify(report));instance.free();scene.free();camera.free();quit(0 if failures.is_empty() else 1)
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<40:failures.append({"label":label,"actual":a,"expected":b,"error":error})
