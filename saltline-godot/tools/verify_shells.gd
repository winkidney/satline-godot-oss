extends SceneTree
class FlatPhysics extends SaltlinePhysics:
 func raycast(_origin:Vector3,_direction:Vector3,_distance:float)->Dictionary:return {"point":Vector3.ZERO,"surface":"metal"}
var failures=[]
var checks=0
var maximum_error=0.0
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/shell-reference.json"))
 var rng=preload("res://scripts/fx_random.gd").new(fixture.tape)
 var scene=SaltlineSourceScene.new();var mesh=MultiMeshInstance3D.new();mesh.multimesh=MultiMesh.new();mesh.multimesh.transform_format=MultiMesh.TRANSFORM_3D;mesh.multimesh.instance_count=int(fixture.cap)
 scene.source={"nodes":[{"name":"fx_shells","id":"shell"}]};scene.source_nodes={"shell":mesh}
 var collision=FlatPhysics.new({"bounds":{},"boxes":[]});var shells=SaltlineShells.new(scene,collision,rng)
 var fields={"px":["pos",0],"py":["pos",1],"pz":["pos",2],"vx":["vel",0],"vy":["vel",1],"vz":["vel",2],"qx":["rotation",0],"qy":["rotation",1],"qz":["rotation",2],"qw":["rotation",3],"wx":["angular",0],"wy":["angular",1],"wz":["angular",2]}
 for step in fixture.rows.size():
  var row=fixture.rows[step];var op=row.op
  if op.kind=="emit":shells.emit(Vector3(op.p[0],op.p[1],op.p[2]),Vector3(op.v[0],op.v[1],op.v[2]))
  elif op.kind=="clear":shells.clear()
  else:shells.update(op.dt)
  compare(shells.next,row.next,"next",0);compare(rng.calls,row.calls,"random calls",0)
  checks+=2
  if shells.euler_order!=row.order:failures.append("Euler order at "+str(step))
  if mesh.visible!=row.visible:failures.append("visibility at "+str(step))
  for i in shells.slots.size():
   var actual=shells.slots[i];var expected=row.slots[i];compare(actual.state,expected.state,"state",0)
   # clear preserves dormant source arrays; their contents have no active effect.
   if actual.state==0:continue
   if op.kind=="update":
    var size=1.0 if actual.rest<4 else 1-(actual.rest-4)/.7
    var transform=Transform3D(shells.shell_basis(actual.rotation,size),actual.pos)
    for axis in 3:
     for component in 3:compare(transform.basis[axis][component],row.matrix[i*16+axis*4+component],"matrix",.000001)
     compare(transform.origin[axis],row.matrix[i*16+12+axis],"matrix position",.000001)
   for key in fields:
    var mapping=fields[key];compare(actual[mapping[0]][mapping[1]],expected[key],"%s/%s/%s"%[step,i,key],.000001)
   for key in ["age","rest","floor","bounces"]:compare(actual[key],expected[key],"%s/%s/%s"%[step,i,key],.000001)
 var report={"checks":checks,"steps":fixture.rows.size(),"draws":rng.calls,"maximum_error":maximum_error,"failures":failures,"source_sha256":fixture.source_sha256,"methods_sha256":fixture.methods_sha256,"scope":"Original Kg methods and quaternion conversion; flat metal floor, ring overwrite, XYZ to ZXY history, clear/reuse, bounce and fade. Includes production matrix construction, no GPU pixels or whole-world collision parity."}
 FileAccess.open("res://evidence/shell-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));mesh.free();scene.free();quit(0 if failures.is_empty() else 1)
func compare(a,b,label:String,tolerance:float)->void:
 checks+=1;var error=abs(float(a)-float(b));maximum_error=maxf(maximum_error,error)
 if not is_finite(error) or error>tolerance:
  if failures.size()<30:failures.append({"label":label,"actual":a,"expected":b,"error":error})
