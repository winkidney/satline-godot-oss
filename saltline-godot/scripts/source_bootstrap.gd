extends RefCounted
# Source normal seed4207 bootstrap. Asset-generation draws are already baked.
const Rng=preload("res://scripts/source_rng.gd")
var root
var streams={}
var bootstrap_data:Dictionary
func _init()->void:
 bootstrap_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/source-bootstrap.json"))
 root=Rng.new(int(bootstrap_data.root.seed))
 for name in ["level","rain","explosives","weapon"]:
  var stream=root.fork();var record=bootstrap_data.streams[name]
  assert(stream.seed==int(record.seed),"Source bootstrap fork mismatch")
  stream.state=int(record.state);stream.calls=int(record.calls);streams[name]=stream
 assert(root.state==int(bootstrap_data.root.state) and root.calls==4,"Source bootstrap root mismatch")
