extends SceneTree
const Planar=preload("res://scripts/planar_camera.gd")
func _initialize()->void:call_deferred("run")
func error(a:Projection,b:Projection)->float:
 var result=0.0
 for col in 4:
  for row in 4:result=maxf(result,absf(a[col][row]-b[col][row]))
 return result
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/planar-camera-reference.json"));var reports=[];var failures=[]
 for i in reference.cases.size():
  var sample=reference.cases[i];var m=Planar.matrix(sample.cameraWorld);var world=Transform3D(Basis(Vector3(m.x.x,m.x.y,m.x.z),Vector3(m.y.x,m.y.y,m.y.z),Vector3(m.z.x,m.z.y,m.z.z)),Vector3(m.w.x,m.w.y,m.w.z));var input=sample.input
  var actual=Planar.compute(world,Planar.matrix(sample.projection),Vector2i(input.width,input.height),input.scale,true,input.far)
  if actual.active!=sample.active:failures.append({"case":i,"gate":"active"})
  if not actual.active:reports.append({"case":i,"active":false});continue
  var errors={"world":error(Planar.projection_transform(actual.world),Planar.matrix(sample.reflectionWorld)),"projection":error(actual.projection,Planar.matrix(sample.clippedProjection)),"sampling":error(actual.sampling,Planar.matrix(sample.reflectionMatrix)),"lod":absf(actual.lod-sample.lod),"scale":actual.scale.distance_to(Vector2(sample.reflScale[0],sample.reflScale[1]))}
  if actual.size!=Vector2i(sample.size[0],sample.size[1]):failures.append({"case":i,"gate":"resolution"})
  for key in errors:
   if errors[key]>.0001:failures.append({"case":i,"component":key,"error":errors[key]})
  reports.append({"case":i,"active":true,"size":actual.size,"errors":errors})
 var report={"cases":reports,"failures":failures,"scope":"Actual original Uw against native reflected camera, preclip sampling matrix, oblique clip matrix, resolution and quality/height gates. CPU math only, no reflected scene or mip/radiance proof. All matrix components and scalar absolute tolerance1e-4; source perspective q.w uses algebraic1/far to avoid cancellation."};var file=FileAccess.open("res://evidence/planar-camera-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
