extends SceneTree
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/combat-feedback-reference.json"))
 var model=SaltlineCombatFeedback.new();var failures=[];var comparisons=0;var max_error=0.0;var animation_index=0
 for frame in data.frames:
  for action in frame.actions:
   match action.type:
    "reset":model.reset()
    "damage":model.player_hit(null if action.pos==null else vec(action.pos))
    "kill":model.enemy_killed(action.kind,frame.frame)
    "hit":
     model.enemy_hit(action.killed,action.weak,action.part,frame.frame)
     var expected=data.animations[animation_index];animation_index+=1;comparisons+=3
     if absf(model.animations.back().duration*1000-expected.options.duration)>1e-9:failures.append("animation duration")
     if expected.options.easing!="ease-out":failures.append("animation easing")
     if absf(float(expected.keys[0].transform.get_slice("scale(",1).trim_suffix(")"))-model.animations.back().scale)>1e-9:failures.append("animation scale")
  model.update([1.0/60,.05,.001,.1][int(frame.frame)%4],vec(frame.pos),frame.yaw,frame.shown)
  if model.hit_kind!=frame.hitKind:failures.append("%d hit kind"%frame.frame)
  if model.feed.size()!=frame.feed.size():failures.append("%d feed size"%frame.frame)
  for index in mini(model.feed.size(),frame.feed.size()):
   for key in ["kind","weak","out"]:
    comparisons+=1
    if model.feed[index][key]!=frame.feed[index][key]:failures.append("%d feed %s"%[frame.frame,key])
   var error=absf(model.feed[index].life-frame.feed[index].life);max_error=maxf(max_error,error);comparisons+=1
   if error>1e-9:failures.append("%d feed life"%frame.frame)
  for index in 4:
   for key in ["life","op","rot"]:
    var error=absf(model.arcs[index][key]-frame.arcs[index][key]);max_error=maxf(max_error,error);comparisons+=1
    if error>1e-9:failures.append("%d arc %d %s"%[frame.frame,index,key])
 var report={"frames":data.frames.size(),"comparisons":comparisons,"failures":failures,"maximum_error":max_error,"scope":"Actual original HUD event callbacks and arc/feed update loops; four-slot damage replacement, angle/opacity quantization, max4 feeds, same-frame weak kill annotation, pause freeze, expiry/reset. Browser animation pixel/easing comparison separate."}
 var file=FileAccess.open("res://evidence/combat-feedback-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
