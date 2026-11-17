extends SceneTree
class Game extends "res://scripts/main.gd":
 var pad_snapshot:Variant=null
 func _read_gamepad()->Variant:return pad_snapshot
var game
var failures=[]
var checks=0
var samples=[]
func _initialize()->void:call_deferred("run")
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func pad(down:bool)->void:
 var buttons=[]
 for i in 20:buttons.append({"pressed":down and i==9,"value":1.0 if down and i==9 else 0.0})
 game.pad_snapshot={"axes":[0,0,0,0],"buttons":buttons}
func tick()->void:
 game._game_tick(1.0/60,{})
func run()->void:
 game=Game.new();root.add_child(game);game.set_process(false);game.set_physics_process(false);game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 pad(false)
 await process_frame
 for quality in ["high","ultra","high"]:
  game.render_quality.apply(game,quality)
  var flags=[]
  for i in 4:
   var before=game.sun_shadow_pass.updates
   game.sun_shadow_pass.update()
   flags.append(game.sun_shadow_pass.updates-before)
   await process_frame
   RenderingServer.force_draw(false)
  expect(flags==([1,1,1,1] if quality=="ultra" else [1,0,1,0]),quality+" shadow cadence")
  samples.append({"quality":quality,"updates":flags})
 game.game_flow.start()
 for i in 160:tick()
 game.enemy_manager.clear();game.player.invulnerable=true
 game.game_flow.pause()
 game.game_ui.buttons.settings.pressed.emit()
 expect(game.game_ui.panel_open,"settings opens")
 pad(true);tick()
 expect(game.game_ui.panel_open and game.game_flow.state=="paused","debounce ignores early Start")
 for i in 30:tick()
 expect(game.game_ui.panel_open,"holding early Start does not close later")
 pad(false);tick();pad(true);tick()
 expect(not game.game_ui.panel_open and game.game_flow.state=="paused","Start closes settings without resuming")
 for i in 4:tick()
 expect(game.game_flow.state=="paused","held Start does not resume")
 pad(false);tick();pad(true);tick()
 expect(game.game_flow.state=="playing","released then Start resumes")
 pad(false);tick();game.game_flow.pause()
 game.game_ui.buttons.settings.pressed.emit();game.game_ui.buttons.controls_tab.pressed.emit()
 for i in 30:tick()
 pad(true);tick()
 expect(not game.game_ui.panel_open and game.game_flow.state=="paused","Start closes controls without resuming")
 var report={"checks":checks,"failures":failures,"samples":samples,"scope":"Actual Main, real shadow pass UPDATE_ONCE cadence High/Ultra/High and normalized Start snapshots. GPU frames rendered; does not assert moving-shadow pixel parity or physical controller delivery."}
 FileAccess.open("res://evidence/quality-pause-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print(JSON.stringify(report));await process_frame;await process_frame;game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
