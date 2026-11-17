extends SceneTree
class MuzzleLightSpy extends SaltlineLightPool:
 var delegate:SaltlineLightPool
 var events=[]
 func flash(position:Vector3,color:int=0xffc880,energy:float=30,radius:float=10,duration:float=.06)->void:
  events.append({"position":position,"color":color,"energy":energy,"radius":radius,"duration":duration})
  delegate.flash(position,color,energy,radius,duration)
var muzzle_lights:MuzzleLightSpy
var game
var frame=0
var records=[]
var failures=[]
var finishing=false
var root_checks=0
var bone_checks=0
var captures=[]
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 muzzle_lights=MuzzleLightSpy.new();muzzle_lights.delegate=game.light_pool;game.weapon_effects.light_pool=muzzle_lights
 game.weapon.fired.disconnect(game._weapon_fired)
 game.weapon.fired.connect(on_shot)
func on_shot(gun:String,definition:Dictionary,spread:float)->void:
 var root_node=game.source_scene.source_nodes[game.weapon.rigs[gun].root["$node"]]
 var muzzle_count=muzzle_lights.events.size()
 var before=root_node.transform;var count=game.weapon.root_motion.random_calls;var flashes=game.weapon_effects.flashes_emitted;var lights=game.light_pool.emitted;var bloom=game.weapon.bloom
 game._weapon_fired(gun,definition,spread)
 if muzzle_lights.events.size()>muzzle_count:
  var event=muzzle_lights.events[-1]
  if event.color!=0xffb060 or event.energy!=definition.flashLight or event.radius!=9 or event.duration!=.05:failures.append("wrong muzzle light parameters")
 var record={"frame":frame,"gun":gun,"bloom":game.weapon.bloom,"expected_bloom":minf(1,bloom+definition.spread.shot),"random_delta":game.weapon.root_motion.random_calls-count,"flash_delta":game.weapon_effects.flashes_emitted-flashes,"light_delta":game.light_pool.emitted-lights,"muzzle_light_delta":muzzle_lights.events.size()-muzzle_count,"old_root_unchanged":before==root_node.transform,"root_impulse":game.weapon.motion_state.kP.v,"camera_recoil":game.player.recoil_pitch}
 records.append(record)
 if frame==205:game.player.alive=false
 if absf(record.bloom-record.expected_bloom)>1e-12:failures.append("bloom order")
 if record.random_delta!=(18 if gun=="rifle" else 17) or record.flash_delta!=1 or record.muzzle_light_delta!=1 or record.light_delta<record.muzzle_light_delta or not record.old_root_unchanged:failures.append(record)
func _process(_delta:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame==180:game.pause_pending=true
 if frame==190:game.game_flow.resume()
 var controls={"move":Vector2.ZERO,"sprint":false,"crouch":false,"jump":frame==55,"interact":false,"fire":frame>=10 and frame<50 or frame in [130,145,160,205],"ads":frame<65,"reload":false,"weapon2":frame==80,"weapon1":false,"swap":false}
 var steps=game.weapon.live_root_steps;var commits=game.weapon_animation.root_commits;var entry_alive=game.player.alive
 game._game_tick(1.0/60,controls)
 var active=game.game_flow.state in ["intro","playing"] and entry_alive
 if game.weapon.live_root_steps!=steps+(1 if active else 0) or game.weapon_animation.root_commits!=commits+(1 if active else 0):failures.append("root ownership frame "+str(frame))
 var expected=game.weapon_animation.last_arm_delta*game.weapon_animation.last_sampled_root
 if active:
  var root_node=game.source_scene.source_nodes[game.weapon.rigs[game.weapon.current].root["$node"]]
  if not root_node.transform.is_equal_approx(expected):failures.append("root overwritten frame "+str(frame))
  if game.weapon.motion_state.stepEv!=0 or game.weapon.motion_state.jumpEv!=0 or game.weapon.motion_state.landEv!=-1:failures.append("player event not consumed")
  root_checks+=1
  for id in game.weapon_animation.bone_targets:
   for target in game.weapon_animation.bone_targets[id]:
    if not target[0].get_bone_pose(target[1]).is_equal_approx(game.source_scene.source_nodes[id].transform):failures.append("bone/proxy mismatch")
    bone_checks+=1
 game._process(1.0/60)
 if game.weapon.live_root_steps!=steps+(1 if active else 0) or game.weapon_animation.root_commits!=commits+(1 if active else 0):failures.append("render repeats D/root")
 if active:
  var rendered=game.source_scene.source_nodes[game.weapon.rigs[game.weapon.current].root["$node"]].transform
  if not rendered.is_equal_approx(expected):failures.append("render overwrites root")
 if frame in [40,160]:call_deferred("capture",frame)
 if frame>=220:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame
 RenderingServer.force_draw(false)
 var path="res://evidence/live-root-%03d.png"%requested
 game.get_viewport().get_texture().get_image().save_png(path);captures.append({"requested_frame":requested,"captured_frame":frame,"path":path})
func finish()->void:
 if not records.any(func(row):return row.gun=="rifle") or not records.any(func(row):return row.gun=="pistol"):failures.append("both guns not exercised")
 var report={"frames":frame,"live_root_checks":root_checks,"bone_proxy_checks":bone_checks,"captures":captures,"shots":records,"failures":failures,"scope":"Actual full GPU Main._weapon_fired via signal wrapper. Per-shot 18/17 weapon RNG draws, single muzzle flash/light via delegating spy (impact lights separately retained) and old root unchanged before sampled animation. D once per live tick/none paused, render no repeat, player events consumed and actual bone proxies dual-written. Rigid arm-group transition only, no original IK or full-world image/impact proof."}
 FileAccess.open("res://evidence/weapon-shot-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game.weapon.fired.disconnect(on_shot);game.weapon_effects.light_pool=game.light_pool;muzzle_lights.free();game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
