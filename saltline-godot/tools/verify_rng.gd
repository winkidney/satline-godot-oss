extends SceneTree
func _initialize()->void:
 var cases=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/rng-source-fixtures.json"))
 var failures=[];var samples=0
 for c in cases:
  var rng=load("res://scripts/source_rng.gd").new(int(c.seed))
  for expected in c.first:
   if int(rng.randf()*4294967296.0)!=int(expected):failures.append("parent seed %s"%c.seed)
   samples+=1
  var child=rng.fork()
  for expected in c.child:
   if int(child.randf()*4294967296.0)!=int(expected):failures.append("fork seed %s"%c.seed)
   samples+=1
  for expected in c.parent:
   if int(rng.randf()*4294967296.0)!=int(expected):failures.append("parent continuation seed %s"%c.seed)
   samples+=1
 var report={"failures":failures,"seeds":cases.size(),"samples":samples,"comparison":"exact unsigned 32-bit output equality, no tolerance","source":"Original active su Mulberry32 and fork"}
 var file=FileAccess.open("res://evidence/rng-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"samples":samples,"comparison":report.comparison}));quit(0 if failures.is_empty() else 1)
