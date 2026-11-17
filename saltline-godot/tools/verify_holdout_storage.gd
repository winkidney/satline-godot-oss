extends SceneTree
const Stubs=preload("res://tools/verify_game_flow.gd")
var mission:SaltlineMission
var player
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var args=OS.get_cmdline_user_args()
 var path=args[0]
 var phase=args[1]
 if not path.begins_with("/tmp/saltline-holdout-") or phase not in ["write","read"]:
  push_error("Use an isolated /tmp/saltline-holdout-* path and write/read phase");quit(1);return
 if phase=="write" and FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 var failures=[]
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"));var rules=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game-rules.json"))
 var physics=Stubs.PhysicsStub.new();player=Stubs.PlayerStub.new();player.tuning=rules.player.duplicate(true)
 var coordinator=SaltlineEnemyCoordinator.new(rules.enemies.duplicate(true),physics,player);var combat=SaltlineCombat.new(physics,player);var manager=Stubs.ManagerStub.new(coordinator,combat)
 mission=SaltlineMission.new(data.modules.level,manager,player,Stubs.NavStub.new(physics),SaltlineSourceRng.new(1337))
 var camera=Camera3D.new();root.add_child(camera);var flow=SaltlineGameFlow.new(mission,camera,path)
 var expected=0 if phase=="write" else 1235
 if flow.best_score!=expected:failures.append("initial best")
 mission.run.merge({"score":1234.6 if phase=="write" else 900,"wavesCleared":2,"kills":12},true)
 flow._score_holdout()
 if flow.holdout_result.best!=1235:failures.append("persisted best")
 if flow.holdout_result.record!=(phase=="write"):failures.append("record flag")
 if phase=="read":
  var file=FileAccess.open(path,FileAccess.WRITE);file.store_string('{"best":2400.5}');file.close()
  flow._score_holdout()
  if flow.holdout_result.best!=2400.5 or flow.holdout_result.record:failures.append("external record refresh")
  var saved=JSON.parse_string(FileAccess.get_file_as_string(path))
  if saved.best!=2400.5:failures.append("lower score overwrote external record")
 var report={"phase":phase,"failures":failures,"result":flow.holdout_result,"isolated_path":path}
 var output=FileAccess.open("res://evidence/holdout-storage-"+phase+".json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
 print(JSON.stringify(report))
 flow.dispose();mission.dispose();manager.dispose();camera.queue_free()
 quit(0 if failures.is_empty() else 1)
