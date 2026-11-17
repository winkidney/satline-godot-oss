extends SceneTree
func _initialize()->void:
 ProjectSettings.set_setting("rendering/saltline/source_depth_24",true);call_deferred("run")
func run()->void:
 var viewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2;camera.near=1;camera.far=3;camera.position=Vector3(0,0,3);viewport.add_child(camera);camera.current=true
 var bridge=load("res://tools/polygon_depth_bridge.gd").new();var compositor=Compositor.new();compositor.compositor_effects=[bridge];camera.compositor=compositor;bridge.prepare_size(viewport.size)
 var mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(4,4);mesh.mesh=quad;viewport.add_child(mesh);var materials={};var modes={"":0.0,"saltline_bias_world_2":2.0,"saltline_bias_world_3":3.0,"saltline_bias_world_4":4.0,"saltline_bias_weapon_3":60.0}
 for mode in modes:
  var shader=Shader.new();shader.code="shader_type spatial;render_mode unshaded"+(","+mode if not mode.is_empty() else "")+";void fragment(){ALBEDO=vec3(1);}";var material=ShaderMaterial.new();material.shader=shader;materials[mode]=material
 var reports=[];var failures=[]
 for msaa in [Viewport.MSAA_DISABLED,Viewport.MSAA_4X]:
  viewport.msaa_3d=msaa
  for profile in [[.1,0.0],[.5,0.0],[.9,0.0],[.5,.1],[.5,-.23]]:
   var depth=float(profile[0]);mesh.rotation.y=profile[1];mesh.position.z=2.0-depth*2.0;var baseline=0.0;var measured_slope=0.0
   for mode in modes:
    mesh.material_override=materials[mode]
    for warm in 6:await process_frame;RenderingServer.force_draw(false)
    var depth_image=bridge.output.get_image();var actual=depth_image.get_pixel(32,32).r;var image=viewport.get_texture().get_image();var color=image.get_pixel(32,32);var format=bridge.format_snapshot()
    if mode.is_empty():baseline=actual;measured_slope=absf(depth_image.get_pixel(48,32).r-depth_image.get_pixel(16,32).r)/32.0
    var delta=(actual-baseline)*16777216.0;var slope_factor=3.0 if mode=="saltline_bias_weapon_3" else float(modes[mode]);var slope=measured_slope;var expected=-modes[mode]*2.0-slope_factor*slope*16777216.0
    if absf(delta-expected)>2.0 or color.r<.99 or format!=RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT:failures.append({"mode":mode,"msaa":msaa,"depth":depth,"delta_q24":delta,"expected_q24":expected,"color":color.r,"format":format})
    reports.append({"mode":mode,"msaa":msaa,"slope":slope,"nominal_source_depth":depth,"source_depth":actual,"delta_q24":delta,"expected_q24":expected,"center_color":color.r,"depth_format":format})
 var report={"engine":Engine.get_version_info(),"profiles":reports,"failures":failures,"scope":"Opt-in D24S8 actual Forward+ reverseZ,private four hardwarebias modes,opaque default material shareddepth/prepass andcolor EQUAL consistency;0/4xMSAA,three flatdepths andtwo rotated planes. Constant signs/weaponx20 andslope factors tested against unbiasedGPU32pixel depth gradient,not CPUtan ideal. Delta tolerance2q24 unchanged. Not originalsame-clipgeometry slope/transparency/fullscene orweapon quantization proof."};FileAccess.open("res://evidence/polygon-engine-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));camera.compositor=null;compositor.compositor_effects.clear();bridge.dispose();mesh.material_override=null;materials.clear();viewport.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
