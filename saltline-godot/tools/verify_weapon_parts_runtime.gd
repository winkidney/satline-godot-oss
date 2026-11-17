extends SceneTree
var game
var frame=0
var failures=[]
var snapshots=[]
var finishing=false
var hold_checks=0
var node_checks=0
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.weapon.slots.pistol.ammo=1;game.weapon.slots.pistol.reserve=0;game.weapon.slots.rifle.ammo=1;game.weapon.slots.rifle.reserve=0
func fail(message:String)->void:
 if failures.size()<20:failures.append(str(frame)+" "+message)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==80:game.weapon.slots.pistol.reserve=15
 if frame==290:game.weapon.slots.rifle.reserve=30
 var input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"jump":false,"interact":false,"ads":false,"fire":frame in [50,270],"reload":frame in [80,290],"weapon2":frame==1,"weapon1":frame==210,"swap":false}
 game._game_tick(1.0/60,input);game._process(1.0/60)
 var parts=game.weapon.parts_motion;var view=game.weapon_animation.parts_view
 var pistol=parts.states.pistol;var rifle=parts.states.rifle
 for role in view.roles:
  if role.ends_with("_magazine"):continue
  var node=game.source_scene.source_nodes[view.roles[role]]
  var value=pistol.slide if role=="pistol_slide" else rifle.slide if role=="rifle_bolt" else pistol.barrel_z if role=="pistol_barrel" else null
  if value!=null and absf(node.position.z-value)>2e-6:fail("node overwrote live position "+role)
  if role=="pistol_barrel" and absf(node.rotation.x-pistol.barrel_pitch)>2e-6:fail("barrel pitch overwritten")
  if role=="pistol_stop" and absf(node.rotation.x-pistol.stop_pitch)>2e-6:fail("slide stop overwritten")
  if role=="pistol_round" and node.visible!=pistol.round_visible:fail("pistol round overwritten")
  if role=="rifle_round" and node.visible!=rifle.round_visible:fail("rifle round overwritten")
  node_checks+=1
 if frame>=55 and frame<80:
  if not pistol.locked or absf(pistol.slide-.036)>1e-10 or absf(pistol.stop_pitch+.06)>1e-10 or pistol.round_visible:fail("empty slide did not hold")
  hold_checks+=1
 if frame==200:
  if pistol.locked or absf(pistol.slide)>1e-10 or absf(pistol.stop_pitch)>1e-10 or not pistol.round_visible:fail("reload did not release slide")
 if frame==280:
  if not rifle.locked or absf(rifle.slide)>1e-10 or rifle.round_visible:fail("rifle yS0 empty closure")
 if frame==408 and rifle.slide<.06:fail("rifle reload did not pull full bolt")
 if frame==460 and (rifle.locked or absf(rifle.slide)>1e-10):fail("rifle reload did not close")
 if frame in [50,55,70,109,148,175,177,200,270,280,402,408,418,420,460]:snapshots.append({"frame":frame,"gun":game.weapon.current,"pistol":pistol.duplicate(true),"rifle":rifle.duplicate(true)})
 if frame in [70,408]:call_deferred("capture",frame)
 if frame>=470:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/parts-runtime-%03d.png"%requested)
func finish()->void:
 var report={"frames":frame,"hold_checks":hold_checks,"node_checks":node_checks,"snapshots":snapshots,"failures":failures,"scope":"Actual Main/Weapon/Parts/View GPU path: empty pistol sustained hold, empty reload release, rifle yS0 closure and reload full-pull/return; actual pinned node positions. No full source image, hand/magazine trajectory or IK proof."}
 FileAccess.open("res://evidence/weapon-parts-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"frames":frame,"hold_checks":hold_checks,"node_checks":node_checks,"failures":failures}));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
