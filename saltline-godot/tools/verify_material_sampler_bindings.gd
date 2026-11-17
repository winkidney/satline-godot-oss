extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source();await RenderingServer.frame_post_draw
 var failures=[];var checked=0;var clamped=0;var material_count=0
 for record in scene.source.materials:
  var material=scene.materials[record.id]
  if not material is ShaderMaterial:continue
  var code=material.shader.code
  if not code.contains("uniform sampler2D albedo_tex:"):continue
  material_count+=1
  for pair in [["map","albedo_tex"],["roughnessMap","orm_tex"],["normalMap","normal_tex"]]:
   var ref=record.props.get(pair[0])
   if not ref is Dictionary or not ref.has("$texture"):continue
   var tex=scene.texture_records[ref["$texture"]];var start=code.find("uniform sampler2D "+pair[1]+":");var end=code.find(";",start);var declaration=code.substr(start,end-start);var clamp=int(tex.wrapS)==1001 and int(tex.wrapT)==1001;var wrap="repeat_disable" if clamp else "repeat_enable";var filter="filter_linear," if int(tex.minFilter)==1006 else "filter_linear_mipmap_anisotropic,";checked+=1
   if clamp:clamped+=1
   if not declaration.contains(wrap) or not declaration.contains(filter):failures.append({"material":record.id,"texture":pair[0],"declaration":declaration})
 var report={"materials":material_count,"sampler_bindings":checked,"clamped_bindings":clamped,"shader_variants":scene.generic_shader_variants.size(),"failures":failures,"scope":"All actual generic shader material sampler hints independently checked against source texture wrap/minFilter records; excludes dedicated sea/ground/arms/FX shaders and does not prove hardware filtering parity."};FileAccess.open("res://evidence/material-sampler-bindings-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
