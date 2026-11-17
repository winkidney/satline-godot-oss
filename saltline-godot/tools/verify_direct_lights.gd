extends SceneTree
func _initialize()->void:call_deferred("run")
func matrix(values:Array)->Projection:
 return Projection(Vector4(values[0],values[1],values[2],values[3]),Vector4(values[4],values[5],values[6],values[7]),Vector4(values[8],values[9],values[10],values[11]),Vector4(values[12],values[13],values[14],values[15]))
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/direct-lights-reference.json"));var owner=Node3D.new();root.add_child(owner);var pipeline=SaltlinePostPipeline.new();pipeline.owner=owner;var target=pipeline._filter(Vector2i(2,1),"res://shaders/source_sun_brdf_probe.gdshader",{},true)
 var sun=FileAccess.get_file_as_string("res://shaders/source_sun_surface.gdshaderinc").replace("instance uniform","uniform")
 var local=FileAccess.get_file_as_string("res://shaders/source_direct_surface.gdshaderinc").replace("instance uniform","uniform").replace(":instance_index(11)","").replace(":instance_index(12)","")
 var shader=Shader.new();shader.code="shader_type canvas_item;render_mode unshaded,blend_disabled;\n"+sun+"\n"+local+"\nuniform int source_probe_camera_mask;uniform vec3 uBase;uniform vec3 uPosition;uniform vec3 uView;uniform mat4 uViewMatrix;uniform float uMetal;uniform float uRough;uniform float uWet;uniform float uClamp;uniform float uGlitter;void fragment(){vec3 normal=vec3(0,1,0),diffuse,specular;sourceDirectTerms(uBase,uMetal,uRough,uWet,normal,normal,normalize(uView),(uViewMatrix*vec4(source_sun_direction,0)).xyz,FRAGCOORD.xy,(uViewMatrix*vec4(uPosition,1)).xyz,uViewMatrix,source_probe_camera_mask,diffuse,specular);if(uClamp>.5)specular=min(specular,vec3(40))*uGlitter;COLOR=vec4(FRAGCOORD.x<1.0?diffuse:specular,1);}";target.material.shader=shader
 target.material.set_shader_parameter("source_sun_active",true);target.material.set_shader_parameter("source_sun_receive_shadow",false);target.material.set_shader_parameter("source_local_ready",true);target.material.set_shader_parameter("source_local_active",true)
 var reports=[];var failures=[];var channels=0;var clamped_cases=0
 for index in reference.cases.size():
  var sample=reference.cases[index];var pixels=PackedFloat32Array(sample.atlas);var texture=ImageTexture.create_from_image(Image.create_from_data(4,11,false,Image.FORMAT_RGBAF,pixels.to_byte_array()))
  target.material.set_shader_parameter("source_local_lights",texture);target.material.set_shader_parameter("uViewMatrix",matrix(sample.matrix));target.material.set_shader_parameter("source_sun_ready",sample.values.uSun>.5);target.material.set_shader_parameter("source_probe_camera_mask",int(sample.values.uMask))
  for key in sample.values:
   if key not in ["uMask","uSun"]:target.material.set_shader_parameter(key,sample.values[key])
  for key in sample.vectors:
   var vector=sample.vectors[key];target.material.set_shader_parameter(key,Vector3(vector[0],vector[1],vector[2]))
  await process_frame;RenderingServer.force_draw(false);var image=target.viewport.get_texture().get_image();var maximum=0.0
  for x in 2:
   for channel in 4:
    var expected=float(sample.pixels[x*4+channel]);var actual=image.get_pixel(x,0)[channel];var error=absf(actual-expected);maximum=maxf(maximum,error);channels+=1
    if error>maxf(.002,absf(expected)*.003) and failures.size()<30:failures.append({"case":index,"term":x,"channel":channel,"expected":expected,"actual":actual,"error":error})
  if sample.values.uClamp>.5 and sample.pixels[4]>=39.9*sample.values.uGlitter:clamped_cases+=1
  reports.append({"case":index,"maximum_error":maximum})
 var report={"cases":reports,"channels":channels,"clamped_cases":clamped_cases,"failures":failures,"scope":"Production sourceDirectTerms with only instance uniforms converted to plain Canvas uniforms. Original NVIDIA Three PointInfo/BRDF independent reference, 72 ten-point+sun+key profiles, mask1/2, visibility, source units, yaw, wetF0, rough/metal, total clamp then glitter. abs.002 orrel.003 unchanged sunBRDF tolerance; no PCSS or nonzero derivative proof."};FileAccess.open("res://evidence/direct-lights-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"cases":reports.size(),"channels":channels,"clamped_cases":clamped_cases,"failures":failures}));target.material.set_shader_parameter("source_local_lights",null);owner.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
