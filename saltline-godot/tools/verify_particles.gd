extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/particle-source-fixtures.json"))
 var pool=load("res://scripts/particles.gd").new(4,true)
 for c in fixture.cases:
  var options:Dictionary=c.options.duplicate()
  if options.has("color"):options.color=Vector3(options.color[0],options.color[1],options.color[2])
  pool.emit(Vector3(c.position[0],c.position[1],c.position[2]),Vector3(c.velocity[0],c.velocity[1],c.velocity[2]),c.life,c.s0,c.s1,options)
 var failures=[];var maximum=0.0;var fields=0
 if not pool.emit(Vector3.ZERO,Vector3.ZERO,1,1,1).is_empty():failures.append("capacity overflow must drop")
 for frame in fixture.frames.size():
  var actual=pool.update(1.0/60,Vector3.ZERO,Vector3(-.8,0,.3),float(frame+1)/60)
  var expected:Array=fixture.frames[frame]
  if actual.size()!=expected.size():failures.append("lifetime frame %d"%frame);continue
  for i in actual.size():
   for j in actual[i].size():
    var difference=absf(float(actual[i][j])-float(expected[i][j]));maximum=maxf(maximum,difference);fields+=1
    if difference>.0001:failures.append("frame %d particle %d field %d"%[frame,i,j])
 var report={"failures":failures,"max_field_error":maximum,"frames":fixture.frames.size(),"fields_compared":fields,"checks":["drag and wind","gravity","turbulence","bounce","kill on floor","stop on floor","sorted output","three color ramps","fade in/out","size easing","rotation","capacity and lifetime"]}
 var file=FileAccess.open("res://evidence/particle-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
