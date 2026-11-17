extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/weapon-detail-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(4,1),"res://shaders/source_sun_brdf_probe.gdshader",{},true)
 var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;\n#include \"res://shaders/source_weapon_detail.gdshaderinc\"\nuniform int uKind;uniform vec3 uPosition;uniform vec3 uNormal;uniform vec3 uWorldNormal;uniform vec3 uBase;uniform vec4 uSurf;uniform float uWidth;uniform float uRain;uniform float uRough;uniform float uMetal;void fragment(){vec3 color=uBase;float rough=uRough,metal=uMetal,height,occ;vec4 debug;sourceWeaponSurface(uKind,uPosition,uNormal,uWorldNormal,uSurf,uWidth,uRain,color,rough,metal,height,occ,debug);COLOR=FRAGCOORD.x<1.0?vec4(color,1):FRAGCOORD.x<2.0?vec4(rough,metal,height,1):FRAGCOORD.x<3.0?vec4(occ,debug.rg,1):vec4(debug.ba,0,1);}";target.material.shader=shader
 var reports=[];var failures=[];var channels=0
 for index in reference.cases.size():
  var sample=reference.cases[index];target.material.set_shader_parameter("uKind",int(sample.kind))
  for key in sample.values:target.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector4(v[0],v[1],v[2],v[3]) if v.size()==4 else Vector3(v[0],v[1],v[2]))
  await process_frame;RenderingServer.force_draw(false);var image=target.viewport.get_texture().get_image();var maximum=0.0
  for x in 4:
   for channel in 4:
    var expected=float(sample.pixels[x*4+channel]);var actual=image.get_pixel(x,0)[channel];var error=absf(actual-expected);maximum=maxf(maximum,error);channels+=1
    if error>maxf(.001,absf(expected)*.0015) and failures.size()<40:failures.append({"case":index,"kind":sample.kind,"pixel":x,"channel":channel,"expected":expected,"actual":actual,"error":error})
  reports.append({"case":index,"maximum_error":maximum})
 var report={"cases":reports,"channels":channels,"failures":failures,"scope":"Production mechanical weapon detail kernel vs independent original NVIDIA Three GLSL,96 positions/attributes/rain/pixelwidth; allfive kinds; four RGBA16F outputs include albedo/rough/metal/height/cavity and noise/drop diagnostics;abs.001 orrel.0015. Not bump derivative or actual vertex attribute proof."};FileAccess.open("res://evidence/weapon-detail-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":reports.size(),"channels":channels,"failures":failures}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
