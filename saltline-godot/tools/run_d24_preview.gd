extends SceneTree
var monitors=[]
var tag="unknown"
func _initialize()->void:
 ProjectSettings.set_setting("rendering/saltline/source_depth_24",true)
 for argument in OS.get_cmdline_user_args():
  if argument.ends_with("-preview"):tag=argument.trim_prefix("--")
 print("SOURCE_D24_PREVIEW ",tag);call_deferred("setup")
func setup()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 var cameras=[["world",game.camera],["weapon",game.view_camera],["sun",game.sun_shadow_pass.camera],["reflection",game.planar_reflection.camera]]
 for entry in cameras:
  var camera:Camera3D=entry[1]
  if camera==null:continue
  var monitor=load("res://tools/depth_format_monitor.gd").new();var compositor=camera.compositor
  if compositor==null:compositor=Compositor.new();camera.compositor=compositor
  var effects=compositor.compositor_effects;effects.append(monitor);compositor.compositor_effects=effects;monitors.append([entry[0],monitor])
func _finalize()->void:
 var snapshots={};var failures=[]
 for entry in monitors:
  var value=entry[1].snapshot();snapshots[entry[0]]=value
  if value.format!=RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT or value.calls<1:failures.append(entry[0])
 if monitors.size()!=4:failures.append("missing camera monitor")
 var report={"preview":tag,"source_depth_24":true,"engine":Engine.get_version_info(),"attachments":snapshots,"failures":failures,"scope":"Actual full scene world/weapon/sun/reflection depth attachment formats duringthe named existing preview. Feature-specific assertions are inits runtime report; this audit doesnot replace them."};FileAccess.open("res://evidence/d24-"+tag+"-context.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
