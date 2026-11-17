extends SceneTree
var checks=0
var failures=[]
func compare(a,b,label:String)->void:
 checks+=1
 if a!=b:failures.append(label)
func _initialize()->void:
 var boot=preload("res://scripts/source_bootstrap.gd").new()
 var ref=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/source-bootstrap.json"))
 var all_streams=boot.streams.duplicate();all_streams.root=boot.root
 for name in all_streams:
  var stream=all_streams[name];var record=ref.root if name=="root" else ref.streams[name]
  compare(stream.seed,int(record.seed),name+" seed");compare(stream.state,int(record.state),name+" state");compare(stream.calls,int(record.calls),name+" calls")
  for j in 64:compare(int(stream.randf()*4294967296.0),int(record.sequence_u32[j]),name+"/"+str(j))
 var report={"checks":checks,"failures":failures,"source_sha256":ref.source_sha256,"observation_sha256":ref.observation_sha256,"scope":ref.scope+" Native post-build seed/state/call counters and first64 raw uint32 outputs for5 streams; avoids decimal JSON float parse equality artifacts."}
 FileAccess.open("res://evidence/source-bootstrap-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
