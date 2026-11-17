extends SceneTree
# Source BD world-space inspection views, using the live Fh and source rig.
var game
var boot_loading
var render_options
var environment_report={}
var gun="rifle"
var view="hip"
var limit=0
var frame=0
var ready=false
var mount:Node3D
var shot_path=""
var original_parents={}
var closeup=false
var reload_time=.62
var ads=false
var action_input={}
var look="south"
var weapon_view="1"
var explicit_time=false
var frozen=false
var empty=false
var events=[]
var initialized_ammo=-1
var initialization_steps=0
var warmup=0
var diagnostic=""
var no_msaa=false
var mirror_y=false
const LOOKS={"south":Vector3(.28,-.01,1),"east":Vector3(1,0,.25),"north":Vector3(-.2,-.01,-1),"west":Vector3(-1,0,.1),"nw":Vector3(-.75,-.01,-.65)}
func _initialize()->void:
 render_options=preload("res://scripts/studio_render_options.gd").new(OS.get_cmdline_user_args())
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--wgun="):gun=arg.get_slice("=",1)
  elif arg.begins_with("--wpose="):view=arg.get_slice("=",1)
  elif arg.begins_with("--wt="):reload_time=float(arg.get_slice("=",1));explicit_time=true
  elif arg=="--wads":ads=true
  elif arg=="--wempty":empty=true
  elif arg.begins_with("--wlook="):look=arg.get_slice("=",1)
  elif arg.begins_with("--wview="):weapon_view=arg.get_slice("=",1)
  elif arg=="--studio-mirror-y":mirror_y=true
  elif arg=="--studio-no-msaa":no_msaa=true
  elif arg.begins_with("--studio-surface="):diagnostic=arg.get_slice("=",1)
  elif arg.begins_with("--studio-warmup="):warmup=int(arg.get_slice("=",1))
  elif arg.begins_with("--studio-frames="):limit=int(arg.get_slice("=",1))
  elif arg.begins_with("--studio-capture="):shot_path=arg.trim_prefix("--studio-capture=")
 call_deferred("setup")
func setup()->void:
 if limit==0:
  boot_loading=preload("res://scripts/boot.gd").new();boot_loading.standalone=true;root.add_child(boot_loading)
  await boot_loading.begin_showcase()
 var views=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-showcase-views.json"))
 if not views.has(gun) or (not views[gun].has(view) and view not in ["hip","ads","sprint","fire","reload","empty","locked","switch"]):
  push_error("Unknown weapon inspection view: "+gun+"/"+view);quit(2);return
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path="";game.showcase_render=true
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game.game_ui.root.visible=false
 environment_report=preload("res://scripts/weapon_studio_environment.gd").isolate(game)
 game.weapon.set_view(weapon_view)
 game.weapon.equip(gun)
 game.weapon.phase_event.connect(func(kind,weapon,phase):events.append([kind,weapon,phase]))
 closeup=views[gun].has(view)
 if closeup:
  mount=game.source_scene.source_nodes[game.weapon.rigs[gun].root["$node"]]
  mount.reparent(game.source_scene);mount.transform=Transform3D(Basis(Vector3.UP,float(views[gun][view][0])),Vector3(0,1.25,0))
  _layers(mount,1)
  var hip=game.weapon.rigs[gun].pose.HIP
  var q=Quaternion(Basis.from_euler(Vector3(hip.r[0],hip.r[1],hip.r[2]),EULER_ORDER_YXZ))
  game.weapon.arms.blend.attach({"p":Vector3(hip.p[0],hip.p[1],hip.p[2]),"q":q})
  for id in game.weapon_animation.arm_group_ids:
   var group=game.source_scene.source_nodes[id];original_parents[id]=group.get_parent().get_path();group.reparent(mount);group.transform=Transform3D.IDENTITY;_layers(group,1)
  var v=views[gun][view]
  game.camera.global_position=Vector3(v[1][0],v[1][1],v[1][2]);game.camera.look_at(Vector3(v[2][0],v[2][1],v[2][2]));game.camera.fov=v[3];game.camera.near=.08;game.camera.far=900;game.view_camera.cull_mask=0
  if empty:
   game.weapon.slots[gun].ammo=0;game.weapon.parts_motion.set_locked(gun,true)
  if explicit_time:
   game.weapon.debug_reload_time=reload_time;game.weapon.debug_reload_empty=empty
  game.weapon.snap(game.player,{})
 else:
  game.camera.global_position=Vector3(0,1.68,4);game.camera.look_at(game.camera.global_position+LOOKS.get(look,LOOKS.south)*50);game.camera.fov=52 if view=="ads" or (ads and view in ["fire","locked"]) else 74;game.camera.near=.08;game.camera.far=900
  game.player.sprinting=view=="sprint";game.player.speed=6 if view=="sprint" else 0
  action_input={"fire":false,"ads":view=="ads" or (ads and view in ["fire","locked"]),"ads_value":0.0}
  if view in ["locked","empty"] or empty:
   game.weapon.slots[gun].ammo=0;game.weapon.parts_motion.set_locked(gun,true)
  if view in ["reload","empty"]:
   game.weapon.debug_reload_time=reload_time;game.weapon.debug_reload_empty=view=="empty"
  game.weapon.debug_flash=view=="fire"
  game.weapon.snap(game.player,action_input)
 game.weapon.snap(game.player,action_input if not closeup else {})
 if closeup:_closeup_step(.016)
 else:_action_step(.016)
 initialization_steps=1
 game.weapon.snap(game.player,action_input if not closeup else {})
 initialized_ammo=game.weapon.slots[gun].ammo
 if view=="switch":
  game.weapon.switch_to("pistol" if gun=="rifle" else "rifle")
  var t=0.0
  while t<(reload_time if explicit_time else .14)-.000001:_action_step(.005);t+=.005
  frozen=true
 if not diagnostic.is_empty():preload("res://scripts/studio_material_diagnostic.gd").apply(game,diagnostic)
 if no_msaa:game.post_pipeline.world_port.msaa_3d=Viewport.MSAA_DISABLED;game.post_pipeline.weapon_port.msaa_3d=Viewport.MSAA_DISABLED
 render_options.apply(game)
 if mirror_y:game.camera.basis.y=-game.camera.basis.y
 ready=true
 if boot_loading!=null:await boot_loading.finish_showcase(game)
func _layers(node:Node,mask:int)->void:
 if node is VisualInstance3D:node.layers=mask
 if mask==1 and node is MeshInstance3D:
  for material in game.weapon_animation.drop_view._materials(node):game.weapon_animation.drop_view._world_material(material)
 for child in node.get_children():_layers(child,mask)
func _process(_dt:float)->bool:
 if not ready:return false
 if Input.is_physical_key_pressed(KEY_ESCAPE):call_deferred("finish");ready=false;return false
 frame+=1
 if closeup:_closeup_step(1.0/60)
 elif not frozen:_action_step(1.0/60)
 game._process(1.0/60)
 preload("res://scripts/weapon_studio_environment.gd").after_frame(game)
 if limit>0 and frame>=limit:ready=false;call_deferred("finish")
 return false
func _closeup_step(dt:float)->void:
 game.weapon.update(dt,{"fire":false,"ads":false},game.player)
 game.weapon.arms.step(dt,game.weapon,Transform3D.IDENTITY)
 game.weapon_animation.live_root_enabled=true
 game.weapon_animation.update(game.weapon)

func _action_step(dt:float)->void:
 game.weapon.update(dt,action_input,game.player)
 var live_root=game.weapon.step_root(dt,action_input,game.player)
 game.weapon_animation.update(game.weapon,live_root)
 game.weapon_effects.update(dt)

func finish()->void:
 for i in warmup:
  game._process(0.0);preload("res://scripts/weapon_studio_environment.gd").after_frame(game)
  await process_frame;RenderingServer.force_draw(false)
 await process_frame;RenderingServer.force_draw(false)
 if not shot_path.is_empty():
  var picture=game.get_viewport().get_texture().get_image()
  if mirror_y or diagnostic.ends_with("-projection"):picture.flip_y()
  picture.save_png(shot_path)
 var hdr_report={}
 if not diagnostic.is_empty() and not shot_path.is_empty():
  var hdr=game.post_pipeline.world_port.get_texture().get_image()
  if not (mirror_y or diagnostic.ends_with("-projection")):hdr.flip_y()
  var file=shot_path.trim_suffix(".png")+".rgb16f"
  FileAccess.open(file,FileAccess.WRITE).store_buffer(hdr.get_data())
  hdr_report={"file":file,"width":hdr.get_width(),"height":hdr.get_height(),"format":hdr.get_format(),"row_order":"top-to-bottom"}
 var failures=[]
 if view=="ads" and game.weapon.ads!=1.0:failures.append("ADS not snapped")
 if view=="sprint" and game.weapon.sprint_blend<.99:failures.append("sprint not snapped")
 if view in ["reload","empty"] and game.weapon.reload.get("t",-1)!=reload_time:failures.append("fixed reload time drift")
 if view=="fire" and (game.weapon.shot_count!=0 or not game.weapon_effects.flashes[gun].node.visible):failures.append("debug flash must be visible without shooting")
 if view=="switch" and not frozen:failures.append("switch not frozen")
 if initialization_steps!=1:failures.append("initialization step count")
 if view=="reload" and initialized_ammo!=game.weapon.slots[gun].mag_size:failures.append("debug reload changed initial ammo")
 if view in ["reload","empty"] and events.has(["reload",gun,"start"]):failures.append("debug reload emitted normal start")
 var bones=[]
 for id in game.weapon_animation.arm_node_ids:
  var record=game.source_scene.records[id]
  if record.type!="Bone":continue
  var ancestor=id
  while game.source_scene.records[ancestor].name not in ["arm-left","arm-right"]:ancestor=game.source_scene.records[ancestor].parent
  var node=game.source_scene.source_nodes[id];var p=node.position;var q=node.quaternion
  bones.append({"side":game.source_scene.records[ancestor].name,"name":record.name,"p":[p.x,p.y,p.z],"q":[q.x,q.y,q.z,q.w]})
 var render_report=render_options.report(game)
 var report={"environment":environment_report,"hdr":hdr_report,"surface_diagnostic":diagnostic,"no_msaa":no_msaa,"mirror_y":mirror_y,"bones":bones,"initialized_ammo":initialized_ammo,"initialization_steps":initialization_steps,"events":events,"render_options":render_report,"failures":failures,"gun":gun,"view":view,"frames":frame,"weapon_view":game.weapon.view,"look":look,"switch_state":game.weapon.switching,"frozen":frozen,"camera":str(game.camera.global_transform),"fov":game.camera.fov,"attached":game.weapon.arms.blend.attached,"arm_groups":game.weapon_animation.arm_group_ids.size(),"live_steps":game.weapon.arms.steps,"reload_time":game.weapon.reload.get("t",-1),"ads":game.weapon.ads,"sprint":game.weapon.sprint_blend,"flash":game.weapon.debug_flash,"scope":"BD closeups and hip/ADS/sprint/debug fire/fixed reload/empty/locked entries with live roots and Fh bones. Switch uses original .005 stepping and frozen pose; wlook/wview included. No source full-frame pixel claim."}
 FileAccess.open("res://evidence/weapon-studio-"+gun+"-"+view+("-"+diagnostic if not diagnostic.is_empty() else "")+("-no-msaa" if no_msaa else "")+("-mirror-y" if mirror_y else "")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
