extends SceneTree
var thunder=[]
var comparisons=0
var maximum=0.0
var maximum_scalar=0.0
var rng_checks=0
func same(a:Variant,b:Variant)->bool:
 comparisons+=1
 if a is Vector3:return same([a.x,a.y,a.z],b)
 if a is Vector4:return same([a.x,a.y,a.z,a.w],b)
 if a is Array or a is PackedVector3Array or a is PackedVector4Array:
  if a.size()!=b.size():return false
  for index in a.size():
   if not same(a[index],b[index]):return false
  return true
 if a is float or a is int:
  var error=absf(a-b);maximum=maxf(maximum,error);return error<1e-5
 return a==b
func _initialize()->void:
 var canonical=OS.get_cmdline_user_args().has("--canonical")
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/rain-canonical-reference.json" if canonical else "res://assets/export/fixtures/rain-reference.json"))
 var scene=SaltlineSourceScene.new();scene.source={"nodes":[],"time":{"t":.05}}
 var stream=SaltlineSourceRng.new(int(reference.seed))
 for j in int(reference.initial.rng_calls):stream.randf()
 var model=SaltlineRain.new(scene) if canonical else SaltlineRain.new(scene,stream,reference.initial)
 model.thunder.connect(func(intensity):thunder.append(intensity));var failures=[]
 for index in reference.frames.size():
  var row=reference.frames[index];model.set_rain(row.target);model.update([1.0/60,.05,.1][index%3],row.fov,row.height,row.interiors,row.openings)
  var actual={"time":model.time,"level":model.level,"timer":model.thunder_timer,"pixel":model.pixel_width,"drip":model.drip,"min":model.boxes_min,"max":model.boxes_max,"sky":model.skylights,"visible":model.level>.01,"thunder":thunder}
  for key in actual:
   if key in ["time","level","timer","pixel","drip"]:
    var error=absf(actual[key]-row[key]);maximum_scalar=maxf(maximum_scalar,error);comparisons+=1
    if not is_finite(float(actual[key])) or error>1e-10:failures.append("%d scalar %s"%[index,key])
   elif key=="thunder":
    comparisons+=1
    if thunder.size()!=row.thunder.size():failures.append("event count")
    else:
     for j in thunder.size():
      if not is_finite(float(thunder[j])) or not is_finite(float(row.thunder[j])) or absf(thunder[j]-row.thunder[j])>1e-10:failures.append("event intensity")
   elif not same(actual[key],row[key]):failures.append("%d %s"%[index,key])
  rng_checks+=2
  if model.rng.state!=int(row.rng_state) or model.rng.calls!=int(row.rng_calls):failures.append("%d RNG state/count"%index)
 var report={"canonical":canonical,"rng_checks":rng_checks,"maximum_scalar_error":maximum_scalar,"source_sha256":reference.source_sha256,"update_sha256":reference.update_sha256,"frames":reference.frames.size(),"comparisons":comparisons,"failures":failures,"maximum_error":maximum,"thunder":thunder.size(),"scope":"Literal original Gw.update closure; historical1337/explicit state or default canonical post40641 stream/timer, same dt, rain fade/visibility/resolution/boxes/skylights and thunder events. Exact RNG state/count; scalar1e-10/vector1e-5. No full rendered storm/source timeline proof."}
 var file=FileAccess.open("res://evidence/rain-canonical-verification.json" if canonical else "res://evidence/rain-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
