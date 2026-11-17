extends SceneTree
var failures=[]
func _initialize()->void:call_deferred("verify")
func grab()->Image:
 await process_frame;RenderingServer.force_draw(false);return root.get_texture().get_image()
func difference(a:Image,b:Image)->Dictionary:
 var x=a.get_data();var y=b.get_data();var maximum=0;var count=0;var sum=0
 for i in mini(x.size(),y.size()):
  var d=absi(int(x[i])-int(y[i]));maximum=maxi(maximum,d);sum+=d
  if d>0:count+=1
 return {"maximum_byte_error":maximum,"different_bytes":count,"mean_byte_error":float(sum)/x.size()}
func verify()->void:
 root.size=Vector2i(640,360)
 var world=Node3D.new();root.add_child(world)
 var camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.2,6);camera.look_at(Vector3(0,0,-12));camera.make_current()
 var image=Image.create(1024,1024,false,Image.FORMAT_RGBA8)
 for y in 1024:
  for x in 1024:
   var v=1.0 if ((x*17+y*29)%31)<15 else 0.0;image.set_pixel(x,y,Color(v,float((x+y)%8)/7,1-v,1))
 image.generate_mipmaps();var texture=ImageTexture.create_from_image(image)
 var shader=Shader.new();shader.code="""shader_type spatial;
 render_mode unshaded,cull_disabled;
 uniform sampler2D fixed_clamp:filter_linear_mipmap_anisotropic_4,repeat_disable;
 uniform sampler2D fixed_repeat:filter_linear_mipmap_anisotropic_4,repeat_enable;
 uniform sampler2D ordinary_clamp:filter_linear_mipmap_anisotropic,repeat_disable;
 uniform sampler2D ordinary_repeat:filter_linear_mipmap_anisotropic,repeat_enable;
 uniform int mode=0;
 void fragment(){vec2 uv=UV*12.0-vec2(.25);vec3 c;if(mode==0)c=texture(fixed_clamp,uv).rgb;else if(mode==1)c=texture(fixed_repeat,uv).rgb;else if(mode==2)c=texture(ordinary_clamp,uv).rgb;else c=texture(ordinary_repeat,uv).rgb;ALBEDO=c;}
 """
 if "--fixed4-alpha" in OS.get_cmdline_user_args():shader.code=shader.code.replace("ALBEDO=c;","ALBEDO=c;ALPHA=.55;")
 var material=ShaderMaterial.new();material.shader=shader
 for key in ["fixed_clamp","fixed_repeat","ordinary_clamp","ordinary_repeat"]:material.set_shader_parameter(key,texture)
 var plane=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2(35,70);plane.mesh=mesh;plane.position.z=-25;plane.material_override=material;world.add_child(plane)
 await grab();await grab()
 var captures={}
 for level in [2,3]:
  root.anisotropic_filtering_level=level
  for mode in 4:
   material.set_shader_parameter("mode",mode);await grab();captures[str(level)+"/"+str(mode)]=await grab()
 var comparisons={}
 for pair in [["2/0","3/0"],["2/1","3/1"],["2/0","2/2"],["2/1","2/3"],["3/1","3/3"]]:
  comparisons[pair[0]+"="+pair[1]]=difference(captures[pair[0]],captures[pair[1]])
 for key in ["2/0=3/0","2/1=3/1","2/0=2/2","2/1=2/3"]:
  if comparisons[key].maximum_byte_error>0:failures.append(key)
 if comparisons["3/1=3/3"].different_bytes==0:failures.append("ordinary8 control did not differ from fixed4")
 var report={"comparisons":comparisons,"failures":failures,"scope":"Actual GPU same shader/material/texture fixed4 clamp/repeat invariant when viewport4->8; ordinary4 equality and ordinary8 non-equality control. Bias0, no postprocess."}
 FileAccess.open(("res://evidence/fixed4-sampler-alpha-verification.json" if "--fixed4-alpha" in OS.get_cmdline_user_args() else "res://evidence/fixed4-sampler-verification.json") if RenderingServer.get_current_rendering_method()=="forward_plus" else "res://evidence/fixed4-sampler-unsupported.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
