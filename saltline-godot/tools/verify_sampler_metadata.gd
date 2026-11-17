extends SceneTree
func _initialize()->void:call_deferred("verify")
func verify()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();var failures=[];var checks=0;var targets=[]
 for record in scene.source.materials:
  if record.name!="fx_decals":continue
  var material=scene.materials[record.id];var code=material.shader.code
  checks+=1
  if "uniform sampler2D albedo_tex:source_color,filter_linear_mipmap_anisotropic_4" not in code:failures.append("decal albedo fixed4")
  for pair in [["normal_tex","filter_linear_mipmap"],["orm_tex","filter_linear_mipmap"]]:
   checks+=1
   var start=code.find("uniform sampler2D "+pair[0]+":");var end=code.find(";",start);var declaration=code.substr(start,end-start)
   if not pair[1] in declaration or "anisotropic" in declaration:failures.append(declaration)
   targets.append(declaration)
 var report={"checks":checks,"failures":failures,"declarations":targets,"scope":"Actual generated decal shader sampler hints for source1x normal/ORM;4x color uses private independent sampler, normal/ORM1x."}
 FileAccess.open("res://evidence/sampler-metadata-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));scene.free();quit(0 if failures.is_empty() else 1)
