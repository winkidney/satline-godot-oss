extends SceneTree
func _initialize()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);var failures=[];var values=[]
 for value in [0.0,.35,1.0,-.5,2.0]:
  var material=scene._material({"id":"wet-test","name":"wet-test","type":"MeshStandardMaterial","props":{},"userData":{"sl":{"uSlWet":{"value":value}}}})
  var actual=material.get_shader_parameter("wetness");values.append({"source":value,"native":actual})
  if actual!=value:failures.append(value)
 var report={"values":values,"failures":failures,"scope":"Production source material importer preserves exported shared wet scalar, including non-default finite values. Texture/shading GPU behavior checked separately."}
 FileAccess.open("res://evidence/material-wet-import.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));scene.queue_free();quit(0 if failures.is_empty() else 1)
