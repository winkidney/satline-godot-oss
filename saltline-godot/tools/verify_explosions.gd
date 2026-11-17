extends SceneTree
func _initialize()->void:
 call_deferred("_verify")
func _verify()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source()
 var fx=load("res://scripts/impact_effects.gd").new();root.add_child(fx);fx.setup(scene,scene.camera)
 var decals=SaltlineDecals.new(scene)
 var lights=load("res://scripts/light_pool.gd").new();root.add_child(lights)
 var effects=load("res://scripts/explosion_effects.gd").new(fx,decals,lights)
 var source=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/explosion-source-fixtures.json"))
 var failures=[];var results=[]
 for reference in source.cases:
  fx.pool.clear();fx.lit_pool.clear();fx.debris.clear();effects.clear()
  var previous=fx.debris.emitted
  effects.explode(Vector3(-18,.45,6),reference.size)
  var actual={"size":reference.size,"lit":fx.lit_pool.particles.size(),"add":fx.pool.particles.size(),"debris":fx.debris.emitted-previous}
  for key in ["lit","add","debris"]:
   if actual[key]!=reference[key]:failures.append("size %s %s expected %s actual %s"%[reference.size,key,reference[key],actual[key]])
  results.append(actual)
 var report={"failures":failures,"cases":results,"source":"Original active fx.explosion, lower/upper size clamp and initial emission counts"}
 var file=FileAccess.open("res://evidence/explosion-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
