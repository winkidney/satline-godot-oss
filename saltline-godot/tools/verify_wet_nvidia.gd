extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var bead_components=OS.get_cmdline_user_args().has("--bead-components")
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/"+("wet-bead-components-nvidia-gl.json" if bead_components else "wet-reference-nvidia-gl.json")));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,2),"res://shaders/source_wet_nvidia_probe.gdshader",{},true);target.viewport.transparent_bg=true;var failures=[];var reports=[];var total=0
 if bead_components:
  var shader=Shader.new();shader.code=target.material.shader.code.replace("COLOR=vec4(w,up,bead,texel.r);","COLOR=vec4(slN3(uPos*170.0),slN3(uPos*410.0+5.0),bead,w);");target.material.shader=shader
 var variant="production"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--bead-input="):variant=arg.get_slice("=",1)
 if variant in ["hash-tail","hash-entry","hash-source-affine"]:
  var noise=FileAccess.get_file_as_string("res://shaders/source_material_noise.gdshaderinc")
  if variant in ["hash-entry","hash-source-affine"]:
   noise=noise.replace("p=sourceNoiseRound3(p);","")
   if variant=="hash-source-affine":noise=noise.replace("fma(p,vec3(.3183099),vec3(.71,.113,.419))","p*.3183099+vec3(.71,.113,.419)")
  else:
   var start=noise.find("float slH(");var end=noise.find("float slN3(")
   noise=noise.substr(0,start)+"float slH(vec3 p){p=sourceNoiseRound3(p);vec3 q=sourceNoiseRound3(fract(sourceNoiseRound3(fma(p,vec3(.3183099),vec3(.71,.113,.419)))));q*=17.0;return fract(q.x*q.y*q.z*(q.x+q.y+q.z));}\n"+noise.substr(end)
  var shader=Shader.new();shader.code=target.material.shader.code.replace('#include "res://shaders/source_material_noise.gdshaderinc"',noise);target.material.shader=shader
 if variant in ["split","fused"]:
  var wet=FileAccess.get_file_as_string("res://shaders/source_wet_surface.gdshaderinc")
  wet=wet.replace("slN3(p*410.0+5.0)","slN3(sourceNoiseRound3(p*410.0)+vec3(5.0))" if variant=="split" else "slN3(fma(p,vec3(410.0),vec3(5.0)))")
  var shader=Shader.new();shader.code=target.material.shader.code.replace('#include "res://shaders/source_wet_surface.gdshaderinc"',wet);target.material.shader=shader
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  target.material.set_shader_parameter("uMacro",Vector4(sample.macro[0],sample.macro[1],sample.macro[2],sample.macro[3]));target.material.set_shader_parameter("uParams",Vector4(sample.params[0],sample.params[1],sample.params[2],sample.params[3]));target.material.set_shader_parameter("uTri",sample.tri);target.material.set_shader_parameter("uTint",sample.tint);target.material.set_shader_parameter("uRain",sample.rain);target.material.set_shader_parameter("uIndoor",sample.indoor);await process_frame;RenderingServer.force_draw(false);var image=target.viewport.get_texture().get_image();var maximum=0.0
  for y in 2:
   for x in 2:
    var pixel=image.get_pixel(x,y)
    for channel in 4:
     total+=1;var expected=float(sample.pixels[(y*2+x)*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error)
     if error>.001 and failures.size()<20:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum,"native":Array(PackedFloat32Array([image.get_pixel(0,0).r,image.get_pixel(0,0).g,image.get_pixel(0,0).b,image.get_pixel(0,0).a])),"reference":sample.pixels.slice(0,4)})
 var report={"variant":variant,"cases":reports,"channels":total,"failures":failures,"scope":"Production FMA hash plus wet preparation vs original NVIDIA GL literal mk SL_FX block,48 position/orientation/rain/triplanar/tint profiles. Explicit footprint substitutes fwidth in original for controlled tests; output wet/up/bead/sample red, RGBA16F absolute.001. Does not cover final tint, roughness, actual derivatives or complete material image."};var file=FileAccess.open("res://evidence/"+("wet-bead-components-nvidia-" if bead_components else "wet-surface-nvidia-")+("verification" if variant=="production" else variant)+".json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"variant":variant,"failures":failures,"maximum_error":reports.map(func(row):return row.maximum_error).max()}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
