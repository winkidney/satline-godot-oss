extends Node3D
var camera:Camera3D
var sun:DirectionalLight3D
var fill_light:OmniLight3D
var window_light:SpotLight3D
var reflection_camera:Camera3D
var reflection:SubViewport
var env:Environment
var content:Node3D
var micro:ShaderMaterial
var wet:ShaderMaterial
var lens:ShaderMaterial
var panel:VBoxContainer
var lab=0
var filtering=true
var wetness=0.9
var planar=true
var styled=false
var fog_enabled=true
var exposure=1.0
var pitch_mm=1.2
var reflection_scale=0.5
var update_interval=1
var elapsed=0
var capturing=false
var objects:Array[Node3D]=[]
var capture_results:Array=[]
var widgets={}
var selector:OptionButton
var reflection_refresh=true
var published_reflection_transform=Transform3D.IDENTITY
var published_projection=Projection()
var reflection_trace:Array=[]
var diagnostic_motion=false
func _ready():
 env=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color(0.045,0.065,0.09)
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color(0.45,0.61,0.78)
 env.ambient_light_energy=0.65
 env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
 var sky=Sky.new();var sky_mat=ProceduralSkyMaterial.new()
 sky_mat.sky_top_color=Color(0.1,0.18,0.32);sky_mat.sky_horizon_color=Color(0.65,0.71,0.78)
 sky.sky_material=sky_mat;env.sky=sky
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 var we=WorldEnvironment.new();we.environment=env;add_child(we)
 sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-34,-38,0);sun.light_color=Color(1.0,0.8,0.6);sun.light_energy=2.5;sun.shadow_enabled=true;add_child(sun)
 fill_light=OmniLight3D.new();fill_light.position=Vector3(-3,4,2);fill_light.light_color=Color(0.4,0.65,1);fill_light.light_energy=3;fill_light.omni_range=14;add_child(fill_light)
 window_light=SpotLight3D.new();window_light.position=Vector3(0,3,-5);window_light.rotation_degrees=Vector3(-15,180,0);window_light.light_color=Color(1,.76,.48);window_light.light_energy=8;window_light.light_volumetric_fog_energy=3;window_light.spot_range=16;window_light.spot_angle=27;window_light.shadow_enabled=true;add_child(window_light)
 camera=Camera3D.new();camera.fov=42;camera.near=0.05;camera.far=100;camera.cull_mask=3;add_child(camera);camera.current=true
 reflection=SubViewport.new();reflection.size=Vector2i(640,400);reflection.own_world_3d=false;reflection.world_3d=get_viewport().world_3d;reflection.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(reflection)
 reflection_camera=Camera3D.new();reflection_camera.cull_mask=1;reflection_camera.near=0.05;reflection_camera.far=100;reflection_camera.fov=42;reflection.add_child(reflection_camera)
 var reflection_env=env.duplicate();reflection_env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;reflection_env.tonemap_exposure=1.0;reflection_env.glow_enabled=false;reflection_camera.environment=reflection_env
 lens=ShaderMaterial.new();lens.shader=load('res://shaders/lens.gdshader')
 var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
 var screen=ColorRect.new();screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);screen.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen.material=lens;layer.add_child(screen)
 _ui()
 _build()
 if '--capture' in OS.get_cmdline_user_args():
  capturing=true;call_deferred('_capture_suite')
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--record-plan='):
   var recorder=load('res://lab_record.gd').new();add_child(recorder);recorder.start(self,arg.trim_prefix('--record-plan='))
func _ui():
 var layer=CanvasLayer.new();layer.layer=3;add_child(layer)
 var bg=PanelContainer.new();bg.position=Vector2(18,18);bg.custom_minimum_size=Vector2(300,0);layer.add_child(bg)
 var margin=MarginContainer.new();for key in ['margin_left','margin_right','margin_top','margin_bottom']:margin.add_theme_constant_override(key,14)
 bg.add_child(margin);panel=VBoxContainer.new();panel.add_theme_constant_override('separation',9);margin.add_child(panel)
 var title=Label.new();title.text='Saltline / Godot 实验';title.add_theme_font_size_override('font_size',23);panel.add_child(title)
 selector=OptionButton.new();for item in ['01 微细节 / filtering','02 湿润 / reflection','03 镜头 / lens','04 窄窗 / light']:selector.add_item(item)
 selector.item_selected.connect(func(v):lab=v;_build());panel.add_child(selector)
 var caption=Label.new();caption.text='独立教学实现，非原作数值复刻\n固定灯光 / 固定机位 / 可逐项关闭';caption.add_theme_font_size_override('font_size',14);panel.add_child(caption)
 _toggle('filtering / 导数过滤',true,func(v):filtering=v;_apply())
 _slider('pitch_mm / 纹理周期',0.3,4.0,1.2,func(v):pitch_mm=v;_apply())
 _slider('wetness / 湿润',0,1,0.9,func(v):wetness=v;_apply())
 _toggle('planar / 平面反射',true,func(v):planar=v;_apply())
 _slider('reflection_scale',0.25,1,0.5,func(v):reflection_scale=v;reflection.size=Vector2i(1280*v,800*v);reflection_refresh=true)
 _slider('update_interval / 帧',1,8,1,func(v):update_interval=roundi(v))
 _toggle('styled / glow + grade + streak',false,func(v):styled=v;_apply())
 _toggle('fog / 体积雾',true,func(v):fog_enabled=v;_apply())
 _slider('exposure / 曝光',0.3,2.5,1,func(v):exposure=v;_apply())
 _toggle('auto_exposure / 自动曝光',false,func(v):var a=CameraAttributesPractical.new();a.auto_exposure_enabled=v;a.auto_exposure_min_sensitivity=100;a.auto_exposure_max_sensitivity=1600;camera.attributes=a)
 var hint=Label.new();hint.text='1 / 2 / 3 / 4 切换实验\n方向键：近远 / 转镜\nR：恢复固定机位\nF12：保存当前截图';hint.add_theme_font_size_override('font_size',14);panel.add_child(hint)
func _toggle(text:String,value:bool,callback:Callable):
 var c=CheckButton.new();c.text=text;c.button_pressed=value;c.toggled.connect(callback);panel.add_child(c);widgets[text.split(" / ")[0]]=c
func _slider(text:String,a:float,b:float,value:float,callback:Callable):
 var l=Label.new();l.text=text+' = '+str(snappedf(value,0.01));panel.add_child(l)
 var s=HSlider.new();s.min_value=a;s.max_value=b;s.step=0.01;s.value=value;s.custom_minimum_size.x=270;s.value_changed.connect(func(v):l.text=text+' = '+str(snappedf(v,0.01));callback.call(v));panel.add_child(s);widgets[text.split(" / ")[0]]=[s,l,text]
func _obj(mesh:Mesh,pos:Vector3,col:Color,scale_v=Vector3.ONE,emit=0.0)->MeshInstance3D:
 var m=MeshInstance3D.new();m.mesh=mesh;m.position=pos;m.scale=scale_v
 var mat=ShaderMaterial.new();mat.shader=load('res://shaders/object.gdshader');mat.set_shader_parameter('color',col);mat.set_shader_parameter('emission',emit);m.material_override=mat;content.add_child(m);objects.append(m);return m
func _build():
 reflection_refresh=true
 if content:
  remove_child(content);content.queue_free()
 content=Node3D.new();add_child(content);objects.clear();micro=null;wet=null
 if lab==0:
  micro=ShaderMaterial.new();micro.shader=load('res://shaders/micro.gdshader')
  var sphere=SphereMesh.new();sphere.radius=0.64;sphere.height=1.28;sphere.radial_segments=96;sphere.rings=48
  for x in [-0.9,0.9]:
   var m=MeshInstance3D.new();m.mesh=sphere;m.position=Vector3(x+0.8,1.1,0);m.material_override=micro;content.add_child(m)
  _obj(BoxMesh.new(),Vector3(0.8,0.15,0),Color(0.12,0.15,0.18),Vector3(3.6,0.3,1.8))
 elif lab==1:
  var floor_mesh=PlaneMesh.new();floor_mesh.size=Vector2(14,14)
  var floor_node=MeshInstance3D.new();floor_node.mesh=floor_mesh;floor_node.layers=2;content.add_child(floor_node)
  wet=ShaderMaterial.new();wet.shader=load('res://shaders/wet.gdshader');wet.set_shader_parameter('reflection_tex',reflection.get_texture());floor_node.material_override=wet
  _obj(BoxMesh.new(),Vector3(-0.6,0.85,-0.6),Color(0.8,0.2,0.06),Vector3(1.2,1.7,1.2))
  _obj(SphereMesh.new(),Vector3(1.5,1.1,0.2),Color(0.07,0.55,0.7))
  _obj(BoxMesh.new(),Vector3(2.9,1.6,-1),Color(0.95,0.65,0.2),Vector3(0.12,3.2,0.12),4)
  _obj(BoxMesh.new(),Vector3(0.7,-0.3,-1.6),Color(0.2,0.9,0.35),Vector3(1.1,1.6,0.6))
 elif lab==2:
  for i in 6:
   _obj(SphereMesh.new(),Vector3(-1.7+i*0.8,0.9,-float(i%2)),Color.from_hsv(float(i)/7,0.65,0.8))
  _obj(BoxMesh.new(),Vector3(0.7,2.2,-1.5),Color(1,0.65,0.18),Vector3(3.4,0.07,0.07),12)
  _obj(BoxMesh.new(),Vector3(0.7,0.1,0),Color(0.08,0.1,0.14),Vector3(7,0.2,5))
 else:
  _obj(BoxMesh.new(),Vector3(0,-.1,0),Color(.18,.2,.22),Vector3(9,.2,10))
  _obj(BoxMesh.new(),Vector3(-3.1,2.4,-3),Color(.35,.36,.34),Vector3(3.8,4.8,.3))
  _obj(BoxMesh.new(),Vector3(3.1,2.4,-3),Color(.35,.36,.34),Vector3(3.8,4.8,.3))
  _obj(BoxMesh.new(),Vector3(0,.7,-3),Color(.35,.36,.34),Vector3(2.4,1.4,.3))
  _obj(BoxMesh.new(),Vector3(0,4.2,-3),Color(.35,.36,.34),Vector3(2.4,1.2,.3))
  _obj(BoxMesh.new(),Vector3(-4.5,2.4,1),Color(.25,.28,.3),Vector3(.3,4.8,8))
  _obj(BoxMesh.new(),Vector3(4.5,2.4,1),Color(.25,.28,.3),Vector3(.3,4.8,8))
  _obj(BoxMesh.new(),Vector3(0,4.9,1),Color(.25,.28,.3),Vector3(9,.2,8))
  _obj(BoxMesh.new(),Vector3(1.5,.65,.3),Color(.22,.3,.34),Vector3(1.3,1.3,1.3))
 _reset_camera();_apply()
func _reset_camera():
 camera.position=Vector3(3.9,2.5,5.7) if lab==1 else Vector3(3.3,2.4,3.5) if lab==3 else Vector3(2.4,1.8,5.1)
 camera.look_at(Vector3(0,1.8,-1.4) if lab==3 else Vector3(0.8,0.9,0))
func _apply():
 if micro:
  micro.set_shader_parameter('filtering',filtering);micro.set_shader_parameter('pitch_mm',pitch_mm)
 if wet:
  wet.set_shader_parameter('wetness',wetness);wet.set_shader_parameter('planar',planar)
 lens.set_shader_parameter('styled',styled and lab==2)
 env.glow_enabled=styled and lab==2;env.glow_intensity=0.45;env.glow_hdr_threshold=1.0
 env.volumetric_fog_enabled=lab==3 and fog_enabled;env.volumetric_fog_density=.04
 env.volumetric_fog_length=18;env.volumetric_fog_gi_inject=0;env.volumetric_fog_albedo=Color(.55,.58,.62)
 env.ambient_light_energy=.15 if lab==3 else .65;fill_light.visible=lab!=3;window_light.visible=lab==3
 sun.rotation_degrees=Vector3(-42,180,0) if lab==3 else Vector3(-34,-38,0)
 env.tonemap_exposure=exposure
 _sync_ui()
func _sync_ui():
 selector.select(lab)
 for key in {"filtering":filtering,"planar":planar,"styled":styled,"fog":fog_enabled}:
  widgets[key].set_pressed_no_signal({"filtering":filtering,"planar":planar,"styled":styled,"fog":fog_enabled}[key])
 for key in {"pitch_mm":pitch_mm,"wetness":wetness,"reflection_scale":reflection_scale,"update_interval":update_interval,"exposure":exposure}:
  var value={"pitch_mm":pitch_mm,"wetness":wetness,"reflection_scale":reflection_scale,"update_interval":update_interval,"exposure":exposure}[key]
  widgets[key][0].set_value_no_signal(value);widgets[key][1].text=widgets[key][2]+" = "+str(snappedf(value,0.01))
func _process(_dt):
 elapsed+=1
 # Input must settle before choosing the camera pose to capture.
 if not capturing:
  if Input.is_key_pressed(KEY_UP):camera.position+=camera.global_basis.z*-0.04
  if Input.is_key_pressed(KEY_DOWN):camera.position+=camera.global_basis.z*0.04
  if Input.is_key_pressed(KEY_LEFT):camera.position.x-=0.03;camera.look_at(Vector3(0.8,0.9,0))
  if Input.is_key_pressed(KEY_RIGHT):camera.position.x+=0.03;camera.look_at(Vector3(0.8,0.9,0))
 var refresh=lab==1 and (reflection_refresh or elapsed%update_interval==0)
 reflection.render_target_update_mode=SubViewport.UPDATE_ONCE if refresh else SubViewport.UPDATE_DISABLED
 if refresh:
  reflection_camera.fov=camera.fov;reflection_camera.position=camera.position*Vector3(1,-1,1)
  var target=camera.position-camera.global_basis.z
  reflection_camera.look_at(target*Vector3(1,-1,1),Vector3.DOWN)
  published_reflection_transform=reflection_camera.global_transform
  published_projection=reflection_camera.get_camera_projection()
  wet.set_shader_parameter('reflected_view',published_reflection_transform.affine_inverse())
  wet.set_shader_parameter('reflected_projection',published_projection)
  reflection_refresh=false
 if diagnostic_motion:
  reflection_trace.append({'frame':elapsed,'refresh':refresh,'main_camera':str(camera.global_transform),'published_reflection':str(published_reflection_transform),'published_projection':str(published_projection)})
func _unhandled_key_input(event):
 if event.is_pressed():
  if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:lab=event.keycode-KEY_1;_build()
  if event.keycode==KEY_R:_reset_camera()
  if event.keycode==KEY_F12:_save('manual')
func _save(name:String):
 var p='res://captures/'+name+'.png';get_viewport().get_texture().get_image().save_png(p)
 var auto_meta={'enabled':false}
 if camera.attributes is CameraAttributesPractical:
  auto_meta={'enabled':camera.attributes.auto_exposure_enabled,'min_sensitivity_iso':camera.attributes.auto_exposure_min_sensitivity,'max_sensitivity_iso':camera.attributes.auto_exposure_max_sensitivity}
 capture_results.append({'auto_exposure':auto_meta,'reflection_resolution':[reflection.size.x,reflection.size.y],'file':name+'.png','lab':lab,'filtering':filtering,'pitch_mm':pitch_mm,'wetness':wetness,'planar':planar,'styled':styled,'exposure':exposure,'camera':str(camera.global_transform),'reflection_update_interval':update_interval,'published_reflection':str(published_reflection_transform),'size':str(get_viewport().get_visible_rect().size)})
func _settle():
 for i in 45:await RenderingServer.frame_post_draw
func _capture_suite():
 for spec in [[0,'micro-filtered',true,0.9,true,false],[0,'micro-unfiltered',false,0.9,true,false],[1,'wet-planar',true,0.95,true,false],[1,'wet-no-planar',true,0.95,false,false],[1,'dry',true,0.0,true,false],[2,'lens-clean',true,0.9,true,false],[2,'lens-styled',true,0.9,true,true]]:
  lab=spec[0];filtering=spec[2];wetness=spec[3];planar=spec[4];styled=spec[5];_build();await _settle();_save(spec[1])
 lab=2;styled=true;_build();widgets['auto_exposure'].button_pressed=true;await _settle();_save('lens-auto-exposure');widgets['auto_exposure'].button_pressed=false
 lab=0;filtering=true;_build()
 camera.position=Vector3(1.3,1.3,2.3);camera.look_at(Vector3(0.8,1.1,0));pitch_mm=4.0;_apply();await _settle();_save('micro-close')
 pitch_mm=1.2;_apply()
 for i in 12:
  camera.position=Vector3(2.1+float(i)*0.035,1.8,4.8);camera.look_at(Vector3(0.8,0.9,0));await _settle();_save('motion-%02d'%i)
 lab=1;wetness=0.0;planar=true;update_interval=1;_build();await _settle();_save('dry-endpoint')
 wetness=1.0;_apply();await _settle();_save('wet-endpoint')
 wetness=0.35;_apply()
 for i in 3:
  camera.position=Vector3(3.1+float(i)*0.6,2.1+float(i)*0.3,5.4);camera.look_at(Vector3(0.8,0.9,0));await _settle();_save('wet-angle-%02d'%i)
 wetness=1.0;update_interval=4;_apply();diagnostic_motion=true
 for i in 16:
  camera.position.x+=0.06;camera.look_at(Vector3(0.8,0.9,0));await get_tree().process_frame;await RenderingServer.frame_post_draw;_save('reflection-motion-%02d'%i)
 diagnostic_motion=false
 var report={'engine' :Engine.get_version_info(),'adapter':RenderingServer.get_video_adapter_name(),'api':RenderingServer.get_video_adapter_api_version(),'renderer':RenderingServer.get_current_rendering_method(),'captures':capture_results,'reflection_update_trace':reflection_trace,'notes':'Teaching approximation. Not a pixel-equivalent port. Reflection clips below-plane fragments in object materials, not oblique camera projection.'}
 var file=FileAccess.open('res://captures/runtime.json',FileAccess.WRITE);file.store_string(JSON.stringify(report,'  '));file.close()
 print('SALTLINE_LABS_CAPTURE_OK '+str(capture_results.size()));get_tree().quit()
