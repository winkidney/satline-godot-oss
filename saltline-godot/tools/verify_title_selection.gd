extends SceneTree
var game
var failures=[]
func _initialize()->void:call_deferred("run")
func settle(count:int=4)->void:
 for i in count:await process_frame
func click_choice(key:String,value:Variant)->void:
 var button
 for item in game.game_ui.choices:
  if item.key==key and item.value==value:button=item.button;break
 if button==null:failures.append("missing "+key);return
 var point=button.get_global_rect().get_center()
 for on in [true,false]:
  var event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=on;Input.parse_input_event(event);await settle()
 if game.game_ui.settings[key]!=value or not button.selected:failures.append("selection "+key)
 for item in game.game_ui.choices:
  if item.key==key and item.value!=value and item.button.selected:failures.append("stale selected "+key)
func run()->void:
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.game_ui.save_path="";await settle(30)
 await click_choice("mode","holdout");await click_choice("difficulty","brutal")
 if game.game_flow.selected_mode!="holdout" or game.mission.difficulty!="brutal":failures.append("selection backend apply")
 await click_choice("mode","mission");await click_choice("difficulty","standard")
 if game.game_flow.selected_mode!="mission" or game.mission.difficulty!="standard":failures.append("selection backend return")
 var report={"failures":failures,"scope":"Actual Main native ScreenTouch clicks holdout/brutal then mission/standard; selected style flags clear siblings, settings and flow/mission apply. No real touch hardware or full title pixel proof."}
 FileAccess.open("res://evidence/title-selection.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
