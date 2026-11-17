class_name SaltlinePostPipeline
extends RefCounted

var motion_port:SubViewport
var motion_material:ShaderMaterial
var motion_enabled=true
var motion_has_history=false
var previous_view_projection=Projection.IDENTITY
var sun_shadow:SaltlineSunShadowPass
var volume_ports=[]
var volume_materials=[]
var volume_enabled=true
var volume_force_unshadowed=false
var volume_sun_color=Vector3(1,.72,.42)
var volume_thunder=0.0
var sun_direction=Vector3(.9163473614874841,.22508532350948027,.33112552036283543)
var solar_projection={}
var world_camera:Camera3D
var weapon_camera:Camera3D
var world_samples:SaltlineDepthSamplesBridge
var weapon_samples:SaltlineDepthSamplesBridge
var combined_depth:SaltlineCombinedDepthBridge
var half_depth:SaltlineHalfDepthBridge
var ao_ports=[]
var ao_materials=[]
var ao_scene:SubViewport
var ao_material:ShaderMaterial
var ao_enabled=true
var owner:Node
var world_port:SubViewport
var scene_port:SubViewport
var weapon_port:SubViewport
var down:Array=[]
var down_materials:Array=[]
var up:Array=[]
var up_materials:Array=[]
var streak:Array=[]
var streak_materials:Array=[]
var dirt_texture:Texture2D
var bloom_enabled=true
var history_port:SubViewport
var adapt_port:SubViewport
var history_material:ShaderMaterial
var adapt_material:ShaderMaterial
var adapt_frames=0
var auto_enabled=true
var ldr_port:SubViewport
var final_material:ShaderMaterial
var material:ShaderMaterial
var quality={"name":"high","scale":1.0}
var quality_shaders={}
var dynamic_scale=1.0

func render_size()->Vector2i:
 return preload("res://scripts/render_quality.gd").resolution(Vector2i(owner.get_viewport().size),quality,1.0,dynamic_scale)

func _quality_shader(path:String,count:int,original:int)->Shader:
 if count==original:return load(path)
 var key=path+str(count)
 if not quality_shaders.has(key):
  var shader=Shader.new();shader.code=FileAccess.get_file_as_string(path).replace("i < %d"%original,"i < %d"%count).replace("float(%d)"%original,"float(%d)"%count);quality_shaders[key]=shader
 return quality_shaders[key]

func set_quality(preset:Dictionary)->void:
 quality=preset.duplicate(true)
 ao_enabled=bool(preset.ao)
 for viewport in ao_ports:viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if ao_enabled else SubViewport.UPDATE_DISABLED
 motion_enabled=bool(preset.motionBlur);motion_has_history=false;volume_enabled=int(preset.volSteps)>0
 ao_materials[0].shader=_quality_shader("res://shaders/source_ao.gdshader",8 if preset.name in ["test","low"] else 16 if preset.name=="ultra" else 12,12)
 volume_materials[0].shader=_quality_shader("res://shaders/source_volume.gdshader",maxi(6,int(preset.volSteps)),24)
 var msaa=Viewport.MSAA_DISABLED if int(preset.msaa)==0 else Viewport.MSAA_2X if int(preset.msaa)==2 else Viewport.MSAA_4X
 world_port.msaa_3d=msaa;weapon_port.msaa_3d=msaa
 set_bloom_enabled(bool(preset.bloom));_resize()

func _viewport(size:Vector2i,hdr:bool=true)->SubViewport:
 var viewport=SubViewport.new();viewport.size=size;viewport.use_hdr_2d=hdr;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;owner.add_child(viewport);return viewport

func _rect(viewport:SubViewport,texture:Texture2D,premultiplied:bool=false)->TextureRect:
 var rect=TextureRect.new();rect.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;rect.texture=texture;rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(rect)
 if premultiplied:
  var composite=ShaderMaterial.new();composite.shader=load("res://shaders/viewmodel_composite.gdshader");rect.material=composite
 return rect

func setup_world(parent:Node,camera:Camera3D)->void:
 owner=parent
 var size=Vector2i(owner.get_viewport().get_visible_rect().size)
 world_port=_viewport(size);world_port.world_3d=owner.get_world_3d();world_port.msaa_3d=owner.get_viewport().msaa_3d
 # Resolve the patched method at runtime so the stock editor can import this project.
 RenderingServer.call("viewport_set_source_raster_y_up",world_port.get_viewport_rid(),true)
 var before=camera.global_transform
 camera.reparent(world_port,true);camera.make_current()
 assert(camera.global_transform.is_equal_approx(before),"Main camera transform changed during viewport migration")
 world_camera=camera;world_samples=_attach_capture(camera)

func _add_effect(camera:Camera3D,effect:CompositorEffect)->void:
 if camera.compositor==null:camera.compositor=Compositor.new()
 var effects=camera.compositor.compositor_effects;effects.append(effect);camera.compositor.compositor_effects=effects

func _attach_capture(camera:Camera3D)->SaltlineDepthSamplesBridge:
 var capture=SaltlineDepthSamplesBridge.new();_add_effect(camera,capture);return capture

func _filter(size:Vector2i,path:String,parameters:Dictionary,hdr:bool=true)->Dictionary:
 var viewport=_viewport(size,hdr);viewport.disable_3d=true
 var filter=ShaderMaterial.new();filter.shader=load(path)
 for key in parameters:filter.set_shader_parameter(key,parameters[key])
 var rect=ColorRect.new();rect.material=filter;rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;viewport.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 return {"viewport":viewport,"material":filter}

func _down_size(previous:Vector2i,index:int)->Vector2i:
 return Vector2i(maxi(4,ceili(previous.x*.5)),maxi(4,ceili(previous.y*.5))) if index==0 else Vector2i(maxi(2,previous.x>>1),maxi(2,previous.y>>1))

func setup(weapon:SubViewport)->void:
 weapon_port=weapon;weapon_port.use_hdr_2d=true
 RenderingServer.call("viewport_set_source_raster_y_up",weapon_port.get_viewport_rid(),true)
 var size=Vector2i(owner.get_viewport().get_visible_rect().size)
 weapon_camera=weapon.get_camera_3d();weapon_samples=_attach_capture(weapon_camera)
 combined_depth=SaltlineCombinedDepthBridge.new();combined_depth.world_samples=world_samples;combined_depth.weapon_samples=weapon_samples;combined_depth.flip_y=true;combined_depth.prepare_size(size);_add_effect(weapon_camera,combined_depth)
 half_depth=SaltlineHalfDepthBridge.new();half_depth.combined_source=combined_depth.output;half_depth.near_plane=world_camera.near;half_depth.far_plane=world_camera.far;half_depth.prepare_size(_down_size(size,0));_add_effect(weapon_camera,half_depth)
 var initial=Image.create(2,2,false,Image.FORMAT_RGBAF);initial.fill(Color(0,0,0,1))
 var history=_filter(Vector2i(2,2),"res://shaders/source_history.gdshader",{"tHistory":ImageTexture.create_from_image(initial)})
 history_port=history.viewport;history_material=history.material;history_material.set_shader_parameter("uSeed",true)
 scene_port=_viewport(size);scene_port.disable_3d=true
 _rect(scene_port,world_port.get_texture()).flip_v=true;_rect(scene_port,weapon_port.get_texture(),true).flip_v=true
 var adapt_texture=history_port.get_texture()
 var half_size=_down_size(size,0);var white=Image.create(2,2,false,Image.FORMAT_RGBAF);white.fill(Color(0,0,0,1));var no_volume=ImageTexture.create_from_image(white)
 var ao=_filter(half_size,"res://shaders/source_ao.gdshader",{"tDepthHalf":half_depth.output,"uRadius":.9,"uIntensity":1.6},false);ao_ports.append(ao.viewport);ao_materials.append(ao.material)
 for axis in 2:
  var blur=_filter(half_size,"res://shaders/source_ao_blur.gdshader",{"tDepthHalf":half_depth.output,"tSrc":ao_ports[axis].get_texture()},false);ao_ports.append(blur.viewport);ao_materials.append(blur.material)
 var shadow_texture:Texture2D=sun_shadow.depth.output if sun_shadow!=null else no_volume
 var shadow_matrix=_matrix(sun_shadow.config.shadowMatrix) if sun_shadow!=null else Projection.IDENTITY
 var volume=_filter(half_size,"res://shaders/source_volume.gdshader",{"tDepthHalf":half_depth.output,"tShadow":shadow_texture,"uShadowMatrix":shadow_matrix,"uHasShadow":1.0 if sun_shadow!=null else 0.0,"uMaxDist":170.0,"uSigma":.0034,"uFarHaze":.42,"uFlicker":0.0,"uBoxDust":6.0,"uBoxMin":Vector3(-16,0,-28),"uBoxMax":Vector3(12,9.5,-11),"uSunDir":sun_direction,"uSunRad":volume_sun_color*7.65,"uAmb":Vector3(.42,.47,.52)*.2,"uZen":Vector3(.055,.085,.13),"uHor":Vector3(.95,.55,.28),"uHorAway":Vector3(.16,.22,.3),"uSunCol":volume_sun_color},true);volume.viewport.transparent_bg=true;volume_ports.append(volume.viewport);volume_materials.append(volume.material)
 for axis in 2:
  var blur=_filter(half_size,"res://shaders/source_volume_blur.gdshader",{"tDepthHalf":half_depth.output,"tSrc":volume_ports[axis].get_texture()},true);blur.viewport.transparent_bg=true;volume_ports.append(blur.viewport);volume_materials.append(blur.material)
 var scene=_filter(size,"res://shaders/source_ao_composite.gdshader",{"tColor":scene_port.get_texture(),"tDepth":combined_depth.output,"tDepthHalf":half_depth.output,"tAO":ao_ports[2].get_texture(),"tVol":volume_ports[2].get_texture(),"tAdapt":adapt_texture,"uExposure":1.0,"uKey":.12,"uMinE":.6,"uMaxE":2.0,"uAuto":1.0,"uNear":world_camera.near,"uFar":world_camera.far,"uAoOn":1.0,"uVolOn":0.0,"uAoStrength":.95,"uHalfRes":Vector2(half_size)})
 ao_scene=scene.viewport;ao_material=scene.material;_resize_ao(size)
 var motion=_filter(size,"res://shaders/source_motion.gdshader",{"tColor":ao_scene.get_texture(),"tDepth":combined_depth.output,"uInvViewProj":Projection.IDENTITY,"uPrevViewProj":Projection.IDENTITY,"uShutter":0.0,"uRes":Vector2(size)},true)
 motion_port=motion.viewport;motion_material=motion.material
 var previous:Texture2D=motion_port.get_texture();var previous_size=size
 for index in 6:
  var target_size=_down_size(previous_size,index)
  var pass_data=_filter(target_size,"res://shaders/source_downsample.gdshader",{"tSrc":previous,"uFirst":1.0 if index==0 else 0.0,"uTexel":Vector2.ONE/Vector2(previous_size)})
  down.append(pass_data.viewport);down_materials.append(pass_data.material);previous=pass_data.viewport.get_texture();previous_size=target_size
 up.resize(5);up_materials.resize(5)
 for index in range(4,-1,-1):
  var pass_data=_filter(down[index].size,"res://shaders/source_upsample.gdshader",{"tLow":previous,"tHigh":down[index].get_texture(),"uTexel":Vector2.ONE/Vector2(previous_size),"uMix":.62})
  up[index]=pass_data.viewport;up_materials[index]=pass_data.material;previous=pass_data.viewport.get_texture();previous_size=down[index].size
 previous=down[2].get_texture()
 for index in 2:
  var pass_data=_filter(down[2].size,"res://shaders/source_streak.gdshader",{"tSrc":previous,"uDir":Vector2(1.5 if index==0 else 5.0,0)/down[2].size.x,"uThreshold":2.2 if index==0 else 0.0,"tAdapt":adapt_texture,"uExposure":1.0,"uKey":.12,"uMinE":.6,"uMaxE":2.0,"uAuto":0.0})
  streak.append(pass_data.viewport);streak_materials.append(pass_data.material);previous=pass_data.viewport.get_texture()
 var adapt=_filter(Vector2i(2,2),"res://shaders/source_adapt.gdshader",{"tPrev":history_port.get_texture(),"tLum":down[5].get_texture(),"tDepth":combined_depth.output,"tWeaponSolarDepth":combined_depth.output,"uUseWeaponDepth":false,"uSunUv":Vector2(.5,.5),"uSunOn":0.0,"uRate":1.0,"uVisRate":1.0,"uAspect":float(size.x)/size.y})
 adapt_port=adapt.viewport;adapt_material=adapt.material
 history.material.set_shader_parameter("tHistory",adapt_port.get_texture())
 dirt_texture=load_source_dirt()
 material=ShaderMaterial.new();material.shader=load("res://shaders/source_composite_data.gdshader")
 var values={"tScene":motion_port.get_texture(),"tBlur":down[1].get_texture(),"tBloom":up[0].get_texture(),"tStreak":streak[1].get_texture(),"tDirt":dirt_texture,"tAdapt":adapt_port.get_texture(),"uExposure":1.0,"uKey":.12,"uMinE":.6,"uMaxE":2.0,"uAuto":0.0,"uAgxMix":.25,"uCA":.0013,"uVignette":.3,"uSaturation":1.0,"uAspect":float(size.x)/size.y,"uSunCol":Vector3(1,.72,.42),"uFlare":.16,"uSunOn":0.0}
 for key in values:material.set_shader_parameter(key,values[key])
 ldr_port=_viewport(size,false);ldr_port.disable_3d=true;ldr_port.transparent_bg=true
 var ldr_rect=ColorRect.new();ldr_rect.material=material;ldr_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;ldr_port.add_child(ldr_rect);ldr_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 final_material=ShaderMaterial.new();final_material.shader=load("res://shaders/source_finish.gdshader")
 for pair in [["tSrc",ldr_port.get_texture()],["uTexel",Vector2.ONE/Vector2(size)],["uTime",0.0],["uGrain",.02],["uSharpen",.3],["uFxaa",1.0]]:final_material.set_shader_parameter(pair[0],pair[1])
 set_bloom_enabled(true);set_auto_exposure(true);owner.get_viewport().size_changed.connect(_resize)

func set_auto_exposure(value:bool)->void:
 auto_enabled=value
 material.set_shader_parameter("uAuto",1.0 if value else 0.0)
 ao_material.set_shader_parameter("uAuto",1.0 if value else 0.0)
 for shader in streak_materials:shader.set_shader_parameter("uAuto",1.0 if value else 0.0)

# Called once for each rendered frame; history stays entirely on GPU.
func tick(dt:float,fast:bool=false,thunder:float=0.0)->void:
 volume_thunder=thunder
 var current=_source_view_projection()
 motion_material.set_shader_parameter("uInvViewProj",current.inverse());motion_material.set_shader_parameter("uPrevViewProj",previous_view_projection)
 motion_material.set_shader_parameter("uShutter",minf(.5,1.0/190.0/maxf(dt,.001)) if motion_enabled and motion_has_history and dt>0 else 0.0)
 previous_view_projection=current;motion_has_history=true
 var time=material.get_shader_parameter("uTime");final_material.set_shader_parameter("uTime",time if time!=null else 0.0)
 solar_projection=SaltlineSolarProjection.project(world_camera,sun_direction)
 var on=solar_projection.on if combined_depth.is_ready() and world_samples.is_ready() and weapon_samples.is_ready() else 0.0
 _update_ao_camera()
 ao_material.set_shader_parameter("uAoOn",1.0 if ao_enabled and half_depth.is_ready() else 0.0)
 var shadow_ready=sun_shadow!=null and (sun_shadow.depth.is_ready_for(sun_shadow.viewport.size) or sun_shadow.resize_pending)
 ao_material.set_shader_parameter("uVolOn",1.0 if volume_enabled and shadow_ready and half_depth.is_ready() else 0.0)
 volume_materials[0].set_shader_parameter("uHasShadow",0.0 if volume_force_unshadowed else 1.0 if shadow_ready else 0.0)
 adapt_material.set_shader_parameter("uSunUv",solar_projection.uv);adapt_material.set_shader_parameter("uSunOn",on)
 material.set_shader_parameter("uSunUv",solar_projection.uv);material.set_shader_parameter("uSunOn",on)
 history_material.set_shader_parameter("uSeed",adapt_frames==0)
 var initial=adapt_frames<2
 adapt_material.set_shader_parameter("uRate",1.0 if initial else .6 if fast else 1.0-exp(-dt/1.5))
 adapt_material.set_shader_parameter("uVisRate",1.0 if initial or fast else 1.0-exp(-dt/.12))
 adapt_frames+=1

# Reconstruct original Three/OpenGL NDC (-1..1 depth), independent of native reverse-Z.
func _source_view_projection()->Projection:
 var native=world_camera.get_camera_projection();var n=world_camera.near;var f=world_camera.far
 var projection=Projection(Vector4(absf(native.x.x),0,0,0),Vector4(0,absf(native.y.y),0,0),Vector4(0,0,-(f+n)/(f-n),-1),Vector4(0,0,-2*f*n/(f-n),0))
 return projection*_world_matrix(world_camera.global_transform.affine_inverse())

func _matrix(a:Array)->Projection:
 return Projection(Vector4(a[0],a[1],a[2],a[3]),Vector4(a[4],a[5],a[6],a[7]),Vector4(a[8],a[9],a[10],a[11]),Vector4(a[12],a[13],a[14],a[15]))

func _world_matrix(t:Transform3D)->Projection:
 return Projection(Vector4(t.basis.x.x,t.basis.x.y,t.basis.x.z,0),Vector4(t.basis.y.x,t.basis.y.y,t.basis.y.z,0),Vector4(t.basis.z.x,t.basis.z.y,t.basis.z.z,0),Vector4(t.origin.x,t.origin.y,t.origin.z,1))

func _update_ao_camera()->void:
 var projection=world_camera.get_camera_projection();var tan_half=Vector2(1.0/absf(projection.x.x),1.0/absf(projection.y.y))
 ao_materials[0].set_shader_parameter("uTanHalf",tan_half);ao_materials[0].set_shader_parameter("uAspect",tan_half.x/tan_half.y)
 half_depth.near_plane=world_camera.near;half_depth.far_plane=world_camera.far;ao_material.set_shader_parameter("uNear",world_camera.near);ao_material.set_shader_parameter("uFar",world_camera.far)
 var volume=volume_materials[0];volume.set_shader_parameter("uTanHalf",tan_half);volume.set_shader_parameter("uCamWorld",_world_matrix(world_camera.global_transform));volume.set_shader_parameter("uCamPos",world_camera.global_position);volume.set_shader_parameter("uFarZ",world_camera.far);volume.set_shader_parameter("uSunDir",sun_direction);volume.set_shader_parameter("uSunRad",volume_sun_color*7.65);volume.set_shader_parameter("uSunCol",volume_sun_color);volume.set_shader_parameter("uAmb",Vector3(.42,.47,.52)*(.2*(1.0+volume_thunder*1.5)))

func _resize_ao(size:Vector2i)->void:
 var half_size=_down_size(size,0)
 for index in 3:
  ao_ports[index].size=half_size;ao_materials[index].set_shader_parameter("uResolution",Vector2(half_size));volume_ports[index].size=half_size
 volume_materials[0].set_shader_parameter("uResolution",Vector2(half_size));volume_materials[1].set_shader_parameter("uDir",Vector2(1.0/half_size.x,0));volume_materials[2].set_shader_parameter("uDir",Vector2(0,1.0/half_size.y))
 ao_materials[0].set_shader_parameter("uTexel",Vector2.ONE/Vector2(half_size));ao_materials[1].set_shader_parameter("uDir",Vector2(1.0/half_size.x,0));ao_materials[2].set_shader_parameter("uDir",Vector2(0,1.0/half_size.y));ao_material.set_shader_parameter("uHalfRes",Vector2(half_size));ao_scene.size=size;_update_ao_camera()

# Original ek is baked once at a fixed resolution. Preserve that source asset.
func load_source_dirt()->Texture2D:
 var bytes=FileAccess.get_file_as_bytes("res://assets/export/textures/source-dirt.rgba8")
 assert(bytes.size()==512*288*4,"Missing original static dirt RGBA8 bake")
 var image=Image.create_from_data(512,288,false,Image.FORMAT_RGBA8,bytes);image.flip_y()
 return ImageTexture.create_from_image(image)

# Gain gate for source-effect comparisons; the graph remains allocated.
func set_bloom_enabled(value:bool)->void:
 bloom_enabled=value
 for pair in [["uBloom",.065],["uDirt",.1],["uStreak",.03]]:material.set_shader_parameter(pair[0],pair[1] if value else 0.0)

func _resize()->void:
 motion_has_history=false
 var size=render_size();combined_depth.prepare_size(size);half_depth.prepare_size(_down_size(size,0));world_port.size=size;scene_port.size=size;weapon_port.size=size;_resize_ao(size)
 motion_port.size=size;motion_material.set_shader_parameter("uRes",Vector2(size))
 var previous=size
 for index in 6:
  down[index].size=_down_size(previous,index);down_materials[index].set_shader_parameter("uTexel",Vector2.ONE/Vector2(previous));previous=down[index].size
 for index in range(4,-1,-1):
  up[index].size=down[index].size;up_materials[index].set_shader_parameter("uTexel",Vector2.ONE/Vector2(previous));previous=up[index].size
 for index in 2:
  streak[index].size=down[2].size;streak_materials[index].set_shader_parameter("uDir",Vector2(1.5 if index==0 else 5.0,0)/down[2].size.x)
 ldr_port.size=size;final_material.set_shader_parameter("uTexel",Vector2.ONE/Vector2(size))
 material.set_shader_parameter("uAspect",float(size.x)/size.y)
 adapt_material.set_shader_parameter("uAspect",float(size.x)/size.y)

func dispose()->void:
 var safe=Image.create(2,2,false,Image.FORMAT_RF);safe.fill(Color(1,0,0,1));var fallback=ImageTexture.create_from_image(safe)
 adapt_material.set_shader_parameter("tDepth",fallback);adapt_material.set_shader_parameter("tWeaponSolarDepth",fallback);adapt_material.set_shader_parameter("uUseWeaponDepth",false)
 motion_port.render_target_update_mode=SubViewport.UPDATE_DISABLED
 ao_scene.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for viewport in ao_ports+volume_ports:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for pair in [[world_camera,world_samples],[weapon_camera,weapon_samples],[weapon_camera,combined_depth],[weapon_camera,half_depth]]:
  if is_instance_valid(pair[0]) and pair[0].compositor!=null:
   var effects=pair[0].compositor.compositor_effects;effects.erase(pair[1]);pair[0].compositor.compositor_effects=effects
  pair[1].dispose()
 if owner.get_viewport().size_changed.is_connected(_resize):owner.get_viewport().size_changed.disconnect(_resize)
