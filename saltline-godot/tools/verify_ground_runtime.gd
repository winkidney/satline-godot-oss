extends SceneTree
var game
var frame=0
var finishing=false
var failures=[]
var events=[]
var wet=Vector3.ZERO
var dry=Vector3.ZERO
var previous_lit=0
var previous_add=0
var checks=0
func _initialize()->void:call_deferred("setup")
func setup()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.flow_preview=true;game.game_flow.start("mission",false,false,true);game.enemy_manager.clear();game._game_tick(0,{});game.flow_preview=false
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/ground-query-reference.json"));var found_wet=false;var found_dry=false
 for row in fixture.rows:
  if row.x< -35 or row.x>25 or row.z< -28 or row.z>28 or not game.navigation.is_walkable(row.x,row.z):continue
  if not found_wet and row.puddle and game.ground_queries.is_puddle(row.x,row.z-1.25) and game.ground_queries.is_puddle(row.x,row.z-2.5) and game.navigation.is_walkable(row.x,row.z-1.25) and game.navigation.is_walkable(row.x,row.z-2.5):wet=Vector3(row.x,0,row.z);found_wet=true
  if not found_dry and not row.puddle:dry=Vector3(row.x,0,row.z);found_dry=true
  if found_wet and found_dry:break
 if not found_wet or not found_dry:failures.append("no navigable ground probes")
 reset_at(wet);game.player.motion_event.connect(observe_motion)
func reset_at(position:Vector3)->void:
 game.player.reset({"pos":position,"yaw":0},game.camera);game.player.pitch=-.65;game.player.invulnerable=true
func observe_motion(kind:String,payload:Dictionary)->void:
 if kind not in ["step","land"]:return
 var position:Vector3=payload.get("pos",game.player.pos) if kind=="step" else game.player.pos
 var water=payload.get("surface","")=="water" or game.ground_queries.is_puddle(position.x,position.z)
 var expected_lit=7 if water else 6 if kind=="land" and float(payload.get("speed",0))>5 else 0
 var size=.9 if kind=="land" else .55 if payload.get("sprint",false) else .4
 var expected_add=roundi(14*minf(size,1.6))+2 if water else 0
 checks+=2
 var lit=game.impact_effects.lit_pool.emitted-previous_lit;var add=game.impact_effects.pool.emitted-previous_add
 if lit!=expected_lit or add!=expected_add:failures.append({"frame":frame,"event":kind,"water":water,"actual":[lit,add],"expected":[expected_lit,expected_add]})
 events.append({"frame":frame,"kind":kind,"surface":payload.get("surface",""),"water":water,"speed":payload.get("speed",0),"lit":lit,"add":add})
 previous_lit=game.impact_effects.lit_pool.emitted;previous_add=game.impact_effects.pool.emitted
func _process(_dt:float)->bool:
 if game==null or finishing:return false
 frame+=1
 if frame in [1,2]:
  var before=game.decals.emitted;var position=wet+Vector3(0,0 if frame==1 else .1,0)
  game._impact_visuals({"point":position,"normal":Vector3.UP,"surface":"concrete"},Vector3.DOWN);checks+=1
  if game.decals.emitted-before!=(0 if frame==1 else 1):failures.append("puddle impact decal routing "+str(frame))
 if frame==80:reset_at(wet)
 if frame==175:
  reset_at(dry);game.player.pos.y=1.4;game.player.on_ground=false;game.player.air_time=.3;game.player.fall_speed=8;game.player.velocity.y=-8
 previous_lit=game.impact_effects.lit_pool.emitted;previous_add=game.impact_effects.pool.emitted
 var input={"move":Vector2(0,1) if frame>=10 and frame<65 else Vector2.ZERO,"sprint":frame>=35 and frame<65,"crouch":false,"jump":frame==81,"interact":false,"ads":false,"fire":false,"reload":false,"weapon2":false,"weapon1":false,"swap":false}
 game._game_tick(1.0/60,input);game._process(1.0/60)
 if frame in [40,135,190]:call_deferred("capture",frame)
 if frame>=240:finishing=true;call_deferred("finish")
 return false
func capture(requested:int)->void:
 await process_frame;RenderingServer.force_draw(false);game.get_viewport().get_texture().get_image().save_png("res://evidence/ground-runtime-%03d.png"%requested)
func finish()->void:
 for kind in ["step","land"]:
  checks+=1
  if not events.any(func(e):return e.kind==kind and e.water):failures.append("missing actual wet "+kind)
 checks+=1
 if not events.any(func(e):return e.kind=="land" and not e.water and float(e.speed)>5):failures.append("missing actual dry hard land")
 var report={"frames":frame,"checks":checks,"wet":[wet.x,wet.y,wet.z],"dry":[dry.x,dry.y,dry.z],"events":events,"failures":failures,"scope":"Actual Main/player physics and motion signals, ground resolver, actual FX counts, wet/dry jump-land and impact decal suppression. Navigable probes and controlled inputs/teleports; no original whole movement timeline or pixel comparison."}
 FileAccess.open("res://evidence/ground-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
