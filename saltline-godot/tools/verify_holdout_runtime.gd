extends SceneTree
var failures=[]
var checks=0
var waves=[]
var supplies=[]
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false)
 for connection in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(connection.callable)
 game.game_flow.storage_path=""
 game.game_flow.start("holdout",false,false,true)
 game.player.invulnerable=true
 game.mission.wave_started.connect(func(wave,count):
  waves.append({"wave":wave,"count":count})
  game.player.health=40
  game.weapon.slots.rifle.reserve=10 if wave==1 else 10000
  game.explosives.items[0].alive=false
 )
 game.mission.resupply.connect(func(amount,cap,reset):supplies.append({"amount":amount,"cap":cap,"reset":reset,"reserve":game.weapon.slots.rifle.reserve,"explosive_alive":game.explosives.items[0].alive}))
 var killed=0
 var frames=0
 while frames<1600 and game.mission.run.wavesCleared<2:
  frames+=1
  for actor in game.enemy_manager.active.duplicate():
   if actor.state.alive:
    actor.damage(100000,actor.state.pos,Vector3.FORWARD,"body");killed+=1
  game._game_tick(.05,{"move":Vector2.ZERO,"fire":false})
  if frames%100==0:await process_frame
 var rules=game.mission.rules.holdout
 expect(waves.size()==2,"two real waves started")
 if waves.size()==2:
  expect(waves[0].count==7 and waves[1].count==9,"source wave counts 7 and 9")
 expect(game.mission.run.wavesCleared==2,"two real waves cleared")
 expect(game.mission.run.kills==16 and killed==16,"real actor death signals scored all 16 kills")
 expect(supplies.size()==2,"one resupply per wave")
 if supplies.size()==2:
  expect(supplies[0].reserve==minf(rules.reserveCap,10+rules.resupply),"odd wave actual rifle refill")
  expect(not supplies[0].reset and not supplies[0].explosive_alive,"odd wave keeps exploded prop")
  expect(supplies[1].reserve==rules.reserveCap,"even wave clamps actual rifle reserve")
  expect(supplies[1].reset and supplies[1].explosive_alive,"even wave resets actual explosive props")
 expect(game.player.health>=40+rules.heal,"actual player receives wave heal")
 expect(game.mission.objective_text()=="Catch your breath","breather objective")
 expect(game.mission.run.breakT==rules.breather,"full breather begins on finish")
 var report={"checks":checks,"failures":failures,"frames":frames,"waves":waves,"supplies":supplies,"score":game.mission.run.score,"kills":game.mission.run.kills,"scope":"Actual Main, enemy actor damage/death signals, spawning queue, rifle reserve, explosive prop reset, player heal, two wave transitions. Controlled lethal damage and invulnerable player; not human combat or rendering acceptance."}
 FileAccess.open("res://evidence/holdout-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
