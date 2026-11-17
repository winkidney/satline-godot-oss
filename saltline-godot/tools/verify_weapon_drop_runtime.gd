extends SceneTree
var game
var frame=0
var finishing=false
var failures=[]
var checks=0
var starts=0
var restores=0
var saved_shaders=[]
var old_parent
var snapshots=[]
var restore_snapshot=[]
var lethal_root_steps=0
func fail(message:String)->void:
 if failures.size()<30:failures.append({"frame":frame,"message":message})
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0.0,{})
 game.weapon.fired.connect(func(_gun,_definition,_spread):
  if frame==20:game.player.invulnerable=false;game.player.damage(200,game.player.pos))
 game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 var view=game.weapon_animation.drop_view
 if frame in [20,230]:
  var node=game.source_scene.source_nodes[game.weapon.rigs[game.weapon.current].root["$node"]]
  old_parent=node.get_parent();saved_shaders.clear()
  for material in game.source_scene.materials.values():
   if material is ShaderMaterial:saved_shaders.append([material,material.shader,material.get_meta("source_polygon_offset_mode","")])
  if frame==20:lethal_root_steps=game.weapon.live_root_steps
  else:game.player.invulnerable=false;game.player.damage(200,game.player.pos)
 if frame in [160,370]:
  restore_snapshot=view.saved.duplicate(true)
  game.game_ui.buttons.retry.pressed.emit();game.enemy_manager.clear();restores+=1
 var input={"fire":frame==20,"ads":false,"weapon2":frame==170}
 game._game_tick(1.0/60,input);game._process(1.0/60)
 if frame==20 and (game.player.alive or game.weapon.live_root_steps!=lethal_root_steps+1):fail("lethal Q tick did not finish exactly one D")
 if frame in [21,230]:
  starts+=1
  if not view.motion.active:fail("death did not start drop")
  if not game.weapon.reload.is_empty() or not game.weapon.switching.is_empty():fail("death did not cancel action")
 if view.motion.active:
  checks+=1
  if view.node.get_parent()!=game.source_scene:fail("dropped root not in world")
  if not view.node.global_position.is_finite():fail("nonfinite dropped position")
  if view.shaders.is_empty():fail("no hardware bias variants migrated")
  var flash=game.source_scene.source_nodes[game.weapon.rigs[view.motion.gun].flash["$node"]]
  for item in view.saved:
   var expected_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if item.node==flash else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
   if item.node.cast_shadow!=expected_shadow:fail("dropped mesh shadow flag incorrect")
   if item.node!=flash and frame not in [21,22,230,231] and not game.sun_shadow_pass.bindings.has(item.node.get_instance_id()):fail("dropped mesh not registered in source sun pass")
   if (item.node.layers&1)==0 or (item.node.layers&2)!=0:fail("dropped mesh layer incorrect")
  for item in view.shaders:
   if not item.material.shader.code.contains("saltline_bias_world_3") or item.material.shader.code.contains("saltline_bias_weapon_3"):fail("dropped bias mode incorrect")
  var time=view.motion.time;var arms=game.weapon.arms.drop_steps
  game.weapon_animation.update(game.weapon);game.weapon_animation.update(game.weapon)
  if time!=view.motion.time or arms!=game.weapon.arms.drop_steps:fail("render advanced drop")
 if frame in [100,310]:
  if not view.motion.resting:fail("dropped weapon did not settle")
  if game.weapon.arms.blend.group_visible.r or game.weapon.arms.blend.group_visible.l:fail("death arms not hidden")
 if frame in [161,371]:
  checks+=1
  if view.motion.active or game.weapon.arms.blend.drop_time>=0:fail("retry retained drop state")
  var id="rifle" if frame==161 else "pistol"
  var node=game.source_scene.source_nodes[game.weapon.rigs[id].root["$node"]]
  if node.get_parent()!=old_parent:fail("retry did not restore parent")
  for item in saved_shaders:
   if item[0].shader!=item[1]:fail("retry did not restore shader")
   if item[0].get_meta("source_polygon_offset_mode","")!=item[2]:fail("retry did not restore bias metadata")
  for item in restore_snapshot:
   if item.node.layers!=item.layers or item.node.cast_shadow!=item.shadow:fail("retry did not restore layer/shadow")
  if not game.weapon.arms.blend.group_visible.r or not game.weapon.arms.blend.group_visible.l:fail("retry did not restore arms")
 if frame in [25,55,245,275]:call_deferred("capture",frame)
 if frame in [20,21,55,100,161,230,275,310,371]:snapshots.append({"frame":frame,"gun":game.weapon.current,"active":view.motion.active,"resting":view.motion.resting,"sunk":view.motion.sunk,"position":view.motion.position.duplicate(),"bounces":view.motion.bounces,"drop_time":game.weapon.arms.blend.drop_time})
 if frame>=400:finishing=true;call_deferred("finish")
 return false
func capture(at:int)->void:
 await process_frame;RenderingServer.force_draw(false)
 game.get_viewport().get_texture().get_image().save_png("res://evidence/drop-runtime-%03d.png"%at)
func finish()->void:
 var report={"frames":frame,"starts":starts,"restores":restores,"checks":checks,"snapshots":snapshots,"failures":failures,"scope":"Actual Main two gun deaths/retries: world reparent/layers/bias variant/restored shader identity/arm hide and restore/no render-only advance. Separate original numerical kernels; no full source combined pixel proof."}
 FileAccess.open("res://evidence/weapon-drop-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
