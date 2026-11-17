extends SceneTree
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hound-locomotion-reference.json"))
 var physics=SaltlinePhysics.new(data.physics);var nav=SaltlineNavigation.new(physics)
 var state={"id":1,"type":"hound","active":true,"pos":Vector3(-32,0,6),"yaw":0.0,"speed":0.0,"prevSpeed":0.0,"yawRate":0.0,"wantYaw":0.0,"maxSpeed":0.0,"push":Vector3.ZERO,"phase":.37,"mode":"patrol","es":"move","esT":0.0}
 var control=SaltlineHoundLocomotion.new(state,nav,data.modules.enemies.TUNE.hound,SaltlineSourceRng.new(9001))
 var wreck={"id":2,"type":"hound","active":true,"alive":false,"pos":Vector3(-31.4,0,6.8)}
 control.set_goal(Vector3(-24,0,6),true)
 var failures=[];var maximum=0.0
 for frame in fixture.frames.size():
  var arrived=control.follow_goal(1.0/60,3.4);control.move(1.0/60,[state,wreck])
  var expected:Dictionary=fixture.frames[frame]
  for field in ["pos","push"]:
   var v:Array=expected[field];var error=state[field].distance_to(Vector3(v[0],v[1],v[2]));maximum=maxf(maximum,error)
   if error>.001:failures.append("frame %d %s"%[frame,field])
  for field in ["yaw","yawRate","speed","maxSpeed","planT"]:
   var error=absf(state[field]-expected[field]);maximum=maxf(maximum,error)
   if error>.001:failures.append("frame %d %s"%[frame,field])
  if state.wp!=expected.wp or state.hasGoal!=expected.hasGoal or state.blocked!=expected.blocked or arrived!=expected.arrived:failures.append("frame %d state"%frame)
 var report={"failures":failures,"frames":fixture.frames.size(),"max_field_error":maximum,"replans":control.replans,"arrived":not state.hasGoal,"source":"Original path follower and exact movement block; real nav/rays and active wreck"}
 var file=FileAccess.open("res://evidence/hound-locomotion-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first_failures":failures.slice(0,5),"max_error":maximum,"arrived":not state.hasGoal}));quit(0 if failures.is_empty() else 1)
