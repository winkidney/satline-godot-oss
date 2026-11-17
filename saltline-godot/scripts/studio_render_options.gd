extends RefCounted
# Shared shot camera/exposure controls for the two source studios.
var camera_values=PackedFloat64Array()
var fov:Variant=null
var exposure:Variant=null
var manual=false
func _init(args:PackedStringArray)->void:
 for arg in args:
  if arg.begins_with("--cam="):
   for value in arg.get_slice("=",1).split(","):camera_values.append(float(value))
  elif arg.begins_with("--fov="):fov=float(arg.get_slice("=",1))
  elif arg.begins_with("--manual-exposure="):manual=true;exposure=float(arg.get_slice("=",1))
  elif arg.begins_with("--exposure="):exposure=float(arg.get_slice("=",1))
func apply(game)->void:
 if camera_values.size()==6:
  var v=camera_values
  game.camera.global_position=Vector3(v[0],v[1],v[2]);game.camera.look_at(Vector3(v[3],v[4],v[5]))
 if fov!=null:game.camera.fov=float(fov)
 if exposure!=null:
  if manual:game.post_pipeline.set_auto_exposure(false)
  for material in [game.post_pipeline.material,game.post_pipeline.ao_material]+game.post_pipeline.streak_materials:material.set_shader_parameter("uExposure",float(exposure))
func report(game)->Dictionary:
 return {"camera":str(game.camera.global_transform),"fov":game.camera.fov,"auto_exposure":game.post_pipeline.auto_enabled,"exposure":game.post_pipeline.material.get_shader_parameter("uExposure")}
