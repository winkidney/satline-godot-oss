extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/solar-projection-reference.json"));var viewport=SubViewport.new();root.add_child(viewport);var camera=Camera3D.new();camera.keep_aspect=Camera3D.KEEP_HEIGHT;camera.near=.08;camera.far=900;viewport.add_child(camera)
 var failures=[];var maximum_uv=0.0;var maximum_active_uv=0.0;var maximum_fade=0.0;var visible=0;var front=0
 for index in data.cases.size():
  var sample=data.cases[index];viewport.size=Vector2i(sample.size[0],sample.size[1]);camera.fov=sample.fov;var a=sample.view
  camera.global_transform=Transform3D(Basis(Vector3(a[0],a[1],a[2]),Vector3(a[4],a[5],a[6]),Vector3(a[8],a[9],a[10])),Vector3(a[12],a[13],a[14]))
  var result=SaltlineSolarProjection.project(camera,Vector3(sample.direction[0],sample.direction[1],sample.direction[2]));var uv=Vector2(sample.result.uv[0],sample.result.uv[1]);var error=result.uv.distance_to(uv);var fade=absf(result.on-float(sample.result.on));maximum_uv=maxf(maximum_uv,error);maximum_fade=maxf(maximum_fade,fade)
  if result.front:maximum_active_uv=maxf(maximum_active_uv,error)
  visible+=int(result.on>0);front+=int(result.front)
  if (result.front and error>maxf(.00002,uv.length()*.00002)) or fade>.00002 or result.front!=sample.result.front:failures.append({"case":index,"uv_error":error,"fade_error":fade,"native":[result.uv.x,result.uv.y],"original":sample.result.uv})
 var report={"cases":data.cases.size(),"failures":failures,"maximum_uv_error":maximum_uv,"maximum_front_uv_error":maximum_active_uv,"maximum_fade_error":maximum_fade,"front":front,"visible":visible,"scope":"Actual original Three solar cameraPos+dir500 projection/frontdot.05/edge1..1.3 fade vs native Camera3D.unproject_position and original bottom-origin UV,640 camera FOV/pitch/roll/aspect transforms. Float32 camera tolerance2e-5 relative UV when frontdot>.05; near-perpendicular UV recorded but not gated because source front gate suppresses flare, fade2e-5; no depth or final flare image comparison."};var file=FileAccess.open("res://evidence/solar-projection-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
