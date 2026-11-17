extends SceneTree
var game
var frame=0
var finishing=false
var failures=[]
var checks=0
func check(condition:bool,message:String)->void:
 checks+=1
 if not condition:failures.append({"frame":frame,"message":message})
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 game.flow_preview=false
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 game.game_ui.save_path="res://evidence/public-ui-settings-test.json"
func select_view(value:int)->void:
 game.game_flow.pause();game.game_ui.open_panel()
 for choice in game.game_ui.choices:
  if choice.key=="view" and choice.value==value:choice.button.pressed.emit()
 var previous_end=-1.0
 for choice in game.game_ui.choices:
  if choice.key=="view":
   check(choice.button.position.x>=previous_end,"weapon choice buttons overlap")
   previous_end=choice.button.position.x+choice.button.size.x
 check(game.weapon.view==value,"real view button did not select pose")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(game.game_ui.save_path))
 check(saved.view==value,"view setting not persisted")
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1;var weapon=game.weapon
 if frame==30:select_view(2)
 if frame==60:select_view(3)
 if frame in [35,65]:game.game_ui.close_panel();game.game_flow.resume()
 if frame==80:weapon.equip("pistol");check(weapon.current=="pistol" and weapon.switching.is_empty(),"immediate equip")
 if frame in [90,95]:
  weapon.set_visible(frame==95)
  check(game.source_scene.source_nodes[weapon.rigs.pistol.root["$node"]].visible==(frame==95),"immediate root visibility")
  for id in game.weapon_animation.arm_group_ids:check(game.source_scene.source_nodes[id].visible==(frame==95),"immediate arm visibility")
 if frame==100:
  weapon.snap(game.player,{"ads":true,"fire":false})
  check(weapon.ads==1 and weapon.motion_state.adsV.x==1,"public snap did not set ADS")
  check(weapon.arms.blend.progress==1,"snap retained transition")
 if frame==110:weapon.slots.pistol.ammo=5;weapon.reload_now()
 if frame==115:
  weapon.equip("rifle");check(weapon.reload.is_empty() and weapon.current=="rifle","equip did not cancel reload")
  check(not game.source_scene.source_nodes[weapon.rigs.pistol.root["$node"]].visible,"old root remained visible")
 if frame==120:
  weapon.set_wetness(.25)
  check(game.source_scene.weapon_wetness==.25,"public wetness mirror")
  for binding in game.source_scene.weapon_wet_materials:check(absf(binding[0].get_shader_parameter(binding[1])-.25)<1e-6,"public wetness shader")
 if frame==130:
  var reserve=weapon.slots.rifle.reserve;weapon.add_ammo(7);check(weapon.slots.rifle.reserve==reserve+7,"public ammo")
 game._game_tick(1.0/60,{"fire":false,"ads":false});game._process(1.0/60)
 if frame in [15,32,45,75,85]:call_deferred("capture",frame)
 if frame>=150:finishing=true;call_deferred("finish")
 return false
func capture(at:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/public-runtime-%03d.png"%at)
func finish()->void:
 var report={"frames":frame,"checks":checks,"failures":failures,"view":game.weapon.view,"scope":"Actual Main/UI buttons select/persist source three weapon positions, live D, immediate equip/visibility/snap/wetness/ammo. Original public contract separately compared; not whole source lifecycle/image proof."}
 FileAccess.open("res://evidence/weapon-public-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
