extends SceneTree
class Recorder extends "res://scripts/tracers.gd":
 func _draw(quads:Array)->void:
  draw_records=quads;quads_drawn=quads.size()

func _initialize()->void:
 var tracer=Recorder.new()
 var frames=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/tracer-source-fixtures.json"))
 tracer.emit(Vector3(0,1,0),Vector3(0,1,-20))
 tracer.update(1.0/60)
 var failures=[];var maximum_error=0.0
 var initial=float(tracer.shots[0].travel)
 if initial<260.0/60*.35 or initial>260.0/60*.75:failures.append("initial random travel range")
 # Align only the RNG sample, not the solver. Godot and browser use different PRNGs.
 tracer.shots[0].travel=frames[0].travel
 for frame in range(1,frames.size()):
  tracer.update(1.0/60)
  var reference:Dictionary=frames[frame]
  if tracer.shots.size()!=reference.count:failures.append("lifetime frame %d"%frame);continue
  if tracer.draw_records.size()!=reference.quads.size():failures.append("layer count frame %d"%frame);continue
  for i in tracer.draw_records.size():
   var q:Array=tracer.draw_records[i];var r:Array=reference.quads[i]
   var actual=[q[0].x,q[0].y,q[0].z,q[1],q[2].x,q[2].y,q[2].z,0,q[3].x,q[3].y,q[3].z,1,q[4],q[5],0,q[6]]
   for j in actual.size():
    var difference=absf(float(actual[j])-float(r[j]));maximum_error=maxf(maximum_error,difference)
    if difference>.0001:failures.append("quad field frame %d layer %d field %d"%[frame,i,j])
 var short=Recorder.new();short.emit(Vector3.ZERO,Vector3(0,0,-.05))
 short.update(1.0/30);short.update(1.0/30)
 if short.shots.size()!=1:failures.append("minimum two rendered frames")
 short.update(1.0/30)
 if short.shots.size()!=0:failures.append("short tracer expires")
 var report={"failures":failures,"max_quad_field_error":maximum_error,"source_frames":frames.size(),"random_alignment":"First sample only; subsequent motion and all three output quads compared with original source","short_tracer_min_frames":2}
 var file=FileAccess.open("res://evidence/tracer-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print(JSON.stringify(report));tracer.free();short.free();quit(0 if failures.is_empty() else 1)
