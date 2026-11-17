extends SceneTree
func _initialize()->void:call_deferred("run")
func tex(color:Color,mips:bool=false)->Texture2D:
 var image=Image.create(64,64,false,Image.FORMAT_RGBAF);image.fill(color)
 if mips:image.generate_mipmaps()
 return ImageTexture.create_from_image(image)
func run()->void:
 var viewport=SubViewport.new();viewport.size=Vector2i(128,128);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;env.environment.ambient_light_color=Color.BLACK;env.environment.ambient_light_energy=1;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.add_child(env)
 var sky=Sky.new();var sky_mat=ShaderMaterial.new();var sky_shader=Shader.new();sky_shader.code="shader_type sky;void sky(){COLOR=vec3(0.0);}";sky_mat.shader=sky_shader;sky.sky_material=sky_mat;env.environment.sky=sky;env.environment.background_mode=Environment.BG_SKY;env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 var camera=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,2,4);camera.look_at(Vector3.ZERO);camera.current=true
 var plane=MeshInstance3D.new();plane.mesh=PlaneMesh.new();plane.mesh.size=Vector2(12,12);viewport.add_child(plane)
 var material=ShaderMaterial.new();material.shader=load("res://shaders/ground.gdshader");plane.material_override=material
 if "--constant" in OS.get_cmdline_user_args():
  var diagnostic=Shader.new();diagnostic.code=material.shader.code.replace("RADIANCE = vec4(pr,pw);","RADIANCE = vec4(.1,8.0,.2,1.0);");material.shader=diagnostic
 if "--simple" in OS.get_cmdline_user_args():
  var diagnostic=Shader.new();diagnostic.code="shader_type spatial;render_mode specular_occlusion_disabled;uniform float uReflOn;void fragment(){ALBEDO=vec3(.1);ROUGHNESS=.1;SPECULAR=.9;RADIANCE=vec4(.1,8.0,.2,uReflOn);}";material.shader=diagnostic
 var values={"uMask":tex(Color(.2,.8,0,.5)),"uMarks":tex(Color.BLACK),"uDetail":tex(Color(.5,.5,0,.5)),"uDetailN":tex(Color(.5,.5,.5,.5)),"uRefl":tex(Color(.1,8,.2,1),true),"uWetG":1.0,"uRain":0.0,"uTime":0.0,"uMaskRect":Vector3(-10,-10,.05),"uMarkRect":Vector4(-10,-10,.05,.05),"uMaskRes":64.0,"uMarkRes":64.0,"uReflMatrix":Projection.IDENTITY,"uReflScale":Vector2(.5,.5),"uReflLod":0.0}
 for key in values:material.set_shader_parameter(key,values[key])
 var samples=[]
 var control=StandardMaterial3D.new();control.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;control.albedo_color=Color.RED;plane.material_override=control
 for warmup in 4:await RenderingServer.frame_post_draw
 var control_pixel=viewport.get_texture().get_image().get_pixel(64,64);print({"control_pixel":control_pixel})
 plane.material_override=material
 for enabled in [false,true]:
  material.set_shader_parameter("uReflOn",1.0 if enabled else 0.0)
  for warmup in 8:await RenderingServer.frame_post_draw
  var image=viewport.get_texture().get_image();var center=image.get_pixel(64,64);samples.append([center.r,center.g,center.b]);image.save_png("res://evidence/planar-radiance-%s.png"%str(enabled))
 var failures=[]
 if samples[0][1]>.002:failures.append("disabled radiance not black")
 if samples[1][1]<.01 or samples[1][1]<samples[1][0]*4:failures.append("synthetic reflected green radiance not contributing")
 var report={"samples":samples,"diagnostic_args":OS.get_cmdline_user_args(),"failures":failures,"scope":"Actual ground RP shader branch with synthetic HDR green mip texture, no lights/ambient, off/on native RADIANCE response. Not real reflection camera, mip generator, or original BRDF parity."};var file=FileAccess.open("res://evidence/planar-radiance-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
