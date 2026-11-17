extends SceneTree
class Game extends "res://scripts/main.gd":
 func _settings_path()->String:return "res://evidence/settings-invalid-input.json" if OS.get_cmdline_user_args().has("--settings-invalid") else "res://evidence/settings-roundtrip-input.json"
var game
var failures=[]
const EXPECTED={"quality":"low","sens":1.85,"invertY":true,"fov":87.0,"difficulty":"brutal","mode":"holdout","view":3}
func _initialize()->void:call_deferred("run")
func run()->void:
 var write=OS.get_cmdline_user_args().has("--settings-write")
 var invalid=OS.get_cmdline_user_args().has("--settings-invalid")
 if invalid:FileAccess.open("res://evidence/settings-invalid-input.json",FileAccess.WRITE).store_string('{"sens":{},"fov":"90","view":"3","quality":42,"difficulty":true,"mode":[],"invertY":[]}')
 game=Game.new();root.add_child(game)
 for i in 30:await process_frame
 if write:
  for key in EXPECTED:game.game_ui._select(key,EXPECTED[key])
  var disk=preload("res://scripts/source_settings.gd").decode(FileAccess.get_file_as_string(game.game_ui.save_path))
  for key in EXPECTED:
   if disk[key]!=EXPECTED[key]:failures.append("disk write "+key)
 elif not invalid:
  for key in EXPECTED:
   if game.game_ui.settings[key]!=EXPECTED[key]:failures.append("new process load "+key)
  if game.render_quality.current!="low":failures.append("loaded quality apply")
  if game.game_flow.selected_mode!="holdout":failures.append("loaded game mode apply")
  if game.mission.difficulty!="brutal":failures.append("loaded difficulty apply")
  if game.weapon.view!=3 or game.player.base_fov!=87:failures.append("loaded view/FOV apply")
 else:
  var expected=preload("res://scripts/source_settings.gd").DEFAULTS.duplicate();expected.invertY=true
  for key in expected:
   if game.game_ui.settings[key]!=expected[key]:failures.append("invalid fallback "+key)
 var phase="invalid" if invalid else "write" if write else "read"
 var report={"phase":phase,"pid":OS.get_process_id(),"settings":game.game_ui.settings,"failures":failures,"scope":"Actual Main/UI _select saves seven non-audio settings to isolated res evidence file; separate process loads through setup, quality/mode/difficulty apply. Invalid phase tests disk-backed wrong-type fallback. No user settings overwrite or physical GUI slider persistence proof."}
 FileAccess.open("res://evidence/settings-roundtrip-"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
