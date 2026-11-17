extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/special-ibl-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,1),"res://shaders/source_cube_uv_probe.gdshader",{},true)
 var body=FileAccess.get_file_as_string("res://shaders/source_ibl_surface.gdshaderinc").replace("instance uniform bool source_ibl_viewmodel:instance_index(10)=false;","uniform bool source_ibl_viewmodel=false;")
 var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;\n#include \"res://shaders/source_sun_brdf.gdshaderinc\"\n"+body+"\nuniform vec3 uBase;uniform vec3 uNormal;uniform vec3 uView;uniform vec3 uOverride;uniform float uRough;uniform float uWet;uniform float uScale;uniform float uWeight;void fragment(){vec3 normal=normalize(uNormal),diffuse,specular;sourceIblTerms(uBase,0.0,uRough,uWet,normal,normal,normalize(uView),mat4(1.0),1.0,uScale,min(uOverride,vec3(48)),uWeight,diffuse,specular);COLOR=vec4(FRAGCOORD.x<1.0?diffuse:specular,1.0);}";target.material.shader=shader
 var envs=preload("res://scripts/pmrem_textures.gd").new();envs.load_source();target.material.set_shader_parameter("source_ibl_sky",envs.textures["30c27fd2-4d7a-42ce-8e91-2cd36adb3c40"]);target.material.set_shader_parameter("source_ibl_room",envs.textures["e44868bb-2bd3-41d6-978b-02a02fedbdf3"]);var reports=[];var failures=[];var channels=0
 for i in reference.cases.size():
  var sample=reference.cases[i]
  for key in sample.values:target.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var v=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(v[0],v[1],v[2]))
  target.material.set_shader_parameter("source_ibl_viewmodel",sample.viewmodel);target.material.set_shader_parameter("source_ibl_view_room",sample.viewroom);target.material.set_shader_parameter("source_ibl_view_fill",sample.fill);await RenderingServer.frame_post_draw;var image=target.viewport.get_texture().get_image();var maximum=0.0
  for x in 2:
   var pixel=image.get_pixel(x,0)
   for channel in 4:
    var expected=float(sample.pixels[x*4+channel]);var error=absf(pixel[channel]-expected);maximum=maxf(maximum,error);channels+=1
    if error>maxf(.001,absf(expected)*.0015) and failures.size()<30:failures.append({"case":i,"channel":channel,"expected":expected,"native":pixel[channel],"error":error})
  reports.append({"case":i,"maximum_error":maximum})
 var report={"cases":reports,"channels":channels,"failures":failures,"scope":"Production sourceIblTerms and originalHDR loader vs literal originalCubeUV/env/BRDF withspecialground/sea/arms preparation;72 profiles,abs.001 orrel.0015. Only instanceuniform becomes equivalent plainuniform forCanvas. Not fullprocedural surfaces or planar capture."};FileAccess.open("res://evidence/special-ibl-gpu-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":reports.size(),"channels":channels,"failures":failures}));owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
