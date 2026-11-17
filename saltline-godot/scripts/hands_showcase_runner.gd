extends SceneTree
# TD non-first-person studio: original straight arm chain, Fh finger model.
const VIEWS={
 "back":[[.2,1.34,.78],[0,1.25,0],26,0],
 "palm":[[.2,1.34,.78],[0,1.25,0],26,PI],
 "side":[[.74,1.3,.34],[0,1.24,0],26,0],
 "arm":[[.62,1.02,.62],[.06,.98,0],30,0]}
var game
var boot_loading
var render_options
var environment_report={}
var studio:Node3D
var view="back"
var pose="relaxed"
var trigger=0.0
var animated_trigger=false
var limit=0
var frame=0
var ready=false
var capture=""
var poses={}
var trigger_samples=[]
var blend_names=PackedStringArray()
var blend_weight:Variant=null
var wetness=.7
var held="rifle"
var explicit_pose=false
var sockets={}
var custom_gun=PackedFloat64Array()
var grip=PackedFloat64Array()
var grip_inputs={}
var pose_updates=0
func _initialize()->void:
 render_options=preload("res://scripts/studio_render_options.gd").new(OS.get_cmdline_user_args())
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--hview="):view=arg.get_slice("=",1)
  elif arg.begins_with("--hpose="):pose=arg.get_slice("=",1);explicit_pose=true
  elif arg.begins_with("--hgun="):custom_gun=_numbers(arg.get_slice("=",1))
  elif arg.begins_with("--hgrip="):grip=_numbers(arg.get_slice("=",1))
  elif arg.begins_with("--hheld="):held=arg.get_slice("=",1)
  elif arg.begins_with("--hblend="):
   blend_names=arg.get_slice("=",1).split(",")
   if blend_names.size()>2:blend_weight=float(blend_names[2])
  elif arg.begins_with("--hwet="):wetness=float(arg.get_slice("=",1))
  elif arg.begins_with("--htrig="):
   var value=arg.get_slice("=",1);animated_trigger=value=="anim";trigger=0 if animated_trigger else float(value)
  elif arg.begins_with("--studio-frames="):limit=int(arg.get_slice("=",1))
  elif arg.begins_with("--studio-capture="):capture=arg.trim_prefix("--studio-capture=")
 call_deferred("setup")
func _numbers(value:String)->PackedFloat64Array:
 var result=PackedFloat64Array()
 if value.is_empty():return result
 for item in value.split(","):result.append(float(item))
 return result

func layers(node:Node)->void:
 if node is VisualInstance3D:node.layers=2 if view=="fp" else 1
 for child in node.get_children():layers(child)
func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 poses=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/hands-showcase-poses.json"))
 sockets=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/hands-showcase-sockets.json"))
 if (not custom_gun.is_empty() and custom_gun.size() not in [3,4,5,6]) or (not grip.is_empty() and grip.size()!=3):
  push_error("hgun requires 3–6 values; hgrip requires 3");quit(2);return
 for number in Array(custom_gun)+Array(grip):
  if not is_finite(number):push_error("Nonfinite studio transform");quit(2);return
 var selected=pose.split(",")
 if (view!="fp" and not VIEWS.has(view)) or held not in ["rifle","pistol"] or not poses.has(selected[0]) or (selected.size()>1 and not poses.has(selected[1])):
  push_error("Unknown hands studio view/pose");quit(2);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path="";game.showcase_render=true
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.game_ui.root.visible=false
 environment_report=preload("res://scripts/weapon_studio_environment.gd").isolate(game)
 for rig in game.weapon.rigs.values():game.source_scene.source_nodes[rig.root["$node"]].visible=false
 studio=Node3D.new();studio.name="hands-studio";game.source_scene.add_child(studio)
 if view=="fp":studio.reparent(game.view_camera);studio.transform=Transform3D.IDENTITY
 else:studio.position=Vector3(0,1.16,0);studio.basis=Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.BACK,float(VIEWS[view][3]))
 for id in game.weapon_animation.arm_group_ids:
  var group=game.source_scene.source_nodes[id];group.reparent(studio);group.transform=Transform3D.IDENTITY;layers(group)
 for side in ["r","l"]:
  var model=game.weapon.arms.models[side]
  model.bones[0].p=[.125 if side=="r" else -.125,0,.57]
  for j in 5:model.bones[j].q=[0,0,0,1]
  model.set_fingers(poses["foregrip" if not grip.is_empty() and not explicit_pose else selected[1] if side=="l" and selected.size()>1 else selected[0]])
 if blend_names.size()>0 and (blend_names.size()<2 or not poses.has(blend_names[0]) or not poses.has(blend_names[1])):
  push_error("Unknown finger blend presets");game._dispose_game();quit(2);return
 game.weapon.arms.live=true
 var v=[[0,1.68,4],[14,1.18,54],74,0] if view=="fp" else VIEWS[view];game.camera.global_position=Vector3(v[0][0],v[0][1],v[0][2]);game.camera.look_at(Vector3(v[1][0],v[1][1],v[1][2]));game.camera.fov=v[2];game.camera.near=.08;game.camera.far=900;game.view_camera.cull_mask=2 if view=="fp" else 0
 _apply_pose()
 render_options.apply(game)
 ready=true
 if boot_loading!=null:await boot_loading.finish_showcase(game)
func _process(_dt:float)->bool:
 if not ready:return false
 frame+=1
 if animated_trigger or (blend_names.size()>=2 and blend_names.size()<3):_apply_pose()
 for model in game.weapon.arms.models.values():model.update(1.0/60)
 trigger_samples.append(game.weapon.arms.models.r.trigger)
 game.weapon_animation._apply_live_arms(game.weapon.arms)
 game._process(1.0/60)
 preload("res://scripts/weapon_studio_environment.gd").after_frame(game)
 # TD owns kh directly; it has no Weapon indoor wetness adaptation or clamp.
 for binding in game.source_scene.weapon_wet_materials:
  if binding[1]=="uArmWet":binding[0].set_shader_parameter(binding[1],wetness)
 if (limit>0 and frame>=limit) or Input.is_physical_key_pressed(KEY_ESCAPE):ready=false;call_deferred("finish")
 return false
func _apply_pose()->void:
 pose_updates+=1
 if blend_names.size()>=2:
  var weight=float(blend_weight) if blend_weight!=null else .5-.5*cos(frame/60.0*1.6)
  var values=PackedFloat32Array();values.resize(20)
  for j in 20:values[j]=lerpf(poses[blend_names[0]][j],poses[blend_names[1]][j],weight)
  for model in game.weapon.arms.models.values():model.set_fingers(values)
 if view=="fp":_grip()
 game.weapon.arms.models.r.set_trigger(.5-.5*cos(frame/60.0*4) if animated_trigger else trigger)
func _grip()->void:
 var pistol=held=="pistol"
 var p=Vector3(.135,-.078,-.5) if pistol else Vector3(.118,-.122,-.275)
 var q=Quaternion(Basis.from_euler(Vector3(.06,.12,-.07) if pistol else Vector3(.034,.085,-.03),EULER_ORDER_YXZ))
 if not custom_gun.is_empty():
  p=Vector3(custom_gun[0],custom_gun[1],custom_gun[2])
  var angles=Vector3.ZERO
  for j in mini(3,custom_gun.size()-3):angles[j]=custom_gun[j+3]
  q=Quaternion(Basis.from_euler(angles,EULER_ORDER_YXZ))
 for side in ["r","l"]:
  var name=("pistol_grip" if pistol else "rifle_grip") if side=="r" else ("pistol_support" if pistol else "foregrip")
  var offset=Vector3(0,-.012,.045) if pistol else Vector3(0,-.055,.085) if side=="r" else Vector3(0,-.04,-.256)
  var anchor=q*offset+p
  var part_q=q
  if not grip.is_empty():
   name="foregrip"
   var sign=1.0 if side=="r" else -1.0
   anchor=Vector3(grip[0]+.11*sign,grip[1],grip[2])
   part_q=Quaternion(Basis(Vector3(0,.86*sign,-.5*sign).normalized(),Vector3(-sign,0,0),Vector3(0,.5,.86).normalized()))
  var wrist=preload("res://scripts/hands_studio_socket.gd").resolve(sockets[name],anchor,part_q,side=="l")
  var wrist_p=wrist.origin
  var wrist_q=wrist.basis.get_rotation_quaternion()
  var model=game.weapon.arms.models[side]
  if not explicit_pose and blend_names.is_empty():model.set_fingers(poses["trigger" if grip.is_empty() and side=="r" and (animated_trigger or trigger!=0) else name])
  grip_inputs[side]={"socket":name,"anchor":[anchor.x,anchor.y,anchor.z],"quaternion":[part_q.x,part_q.y,part_q.z,part_q.w]}
  model.solve([.19 if side=="r" else -.19,-.24,.1],[wrist_p.x,wrist_p.y,wrist_p.z],[wrist_q.x,wrist_q.y,wrist_q.z,wrist_q.w],null,.15 if not grip.is_empty() else .2)

func finish()->void:
 await process_frame;RenderingServer.force_draw(false)
 if not capture.is_empty():game.get_viewport().get_texture().get_image().save_png(capture)
 var failures=[]
 var wet_bindings=0
 for binding in game.source_scene.weapon_wet_materials:
  if binding[1]=="uArmWet":
   wet_bindings+=1
   if absf(float(binding[0].get_shader_parameter(binding[1]))-wetness)>0.000001:failures.append("TD arm wet uniform mismatch")
 if wet_bindings==0:failures.append("TD arm material missing")
 var expected_updates=frame+1 if animated_trigger or (blend_names.size()>=2 and blend_names.size()<3) else 1
 if pose_updates!=expected_updates:failures.append("TD pose update cadence")
 for side in ["r","l"]:
  for bone in game.weapon.arms.models[side].bones:
   for value in bone.p+bone.q:
    if not is_finite(float(value)):failures.append("nonfinite bone "+side)
 if animated_trigger and frame>1 and trigger_samples[0]==trigger_samples[-1]:failures.append("trigger failed to animate")
 var render_report=render_options.report(game)
 var report={"environment":environment_report,"render_options":render_report,"failures":failures,"trigger_first":trigger_samples[0],"view":view,"held":held,"custom_gun":Array(custom_gun),"grip":Array(grip),"grip_inputs":grip_inputs,"blend":Array(blend_names),"pose":pose,"frames":frame,"pose_updates":pose_updates,"arm_wetness":wetness,"wet_bindings":wet_bindings,"studio_transform":str(studio.transform),"arm_groups":game.weapon_animation.arm_group_ids.size(),"trigger":game.weapon.arms.models.r.trigger,"scope":"Original TD static studio views with live Fh finger/trigger updates, world layer and original straight arm chain. Default TD fp rifle/pistol sockets included; custom hgun/hgrip inputs included; no full-frame original pixel parity claim."}
 var case_name=view+("-custom-grip" if not grip.is_empty() else "-custom-gun" if not custom_gun.is_empty() else "-"+held if view=="fp" else "")
 FileAccess.open("res://evidence/hands-studio-"+case_name+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
