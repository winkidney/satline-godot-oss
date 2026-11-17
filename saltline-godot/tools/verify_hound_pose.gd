extends SceneTree
class FlatPhysics extends "res://scripts/source_physics.gd":
 func _init()->void:super({"boxes":[],"bounds":{}})
 func ground_height(_x:float,_z:float,_ceiling:float=50)->float:return 0
func _initialize()->void:call_deferred("_verify")
func _verify()->void:
 var scene=SaltlineSourceScene.new();root.add_child(scene);scene.load_source()
 var record:Dictionary=scene.source.modules.enemies.debug.hounds[0]
 var controller=SaltlineHoundPose.new(scene,record,FlatPhysics.new());controller.state.phase=.37;controller.state.tyaw=.2;controller.state.tpitch=-.05;controller.state.hpitch=.1;controller.state.hyaw=-.3
 controller.reset(Vector3(-30,0,8),.4)
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hound-pose-reference.json"))
 var failures=[];var maximum=0.0;var fields=0
 for frame in fixture.frames.size():
  var state:Dictionary=controller.state
  state.prevSpeed=state.speed;state.speed=minf(3,frame*.04) if frame<120 else maxf(0,3-(frame-120)*.05)
  state.yawRate=.45 if frame>=60 and frame<160 else 0;state.yaw+=state.yawRate/60
  state.pos.x+=sin(state.yaw)*state.speed/60;state.pos.z+=cos(state.yaw)*state.speed/60
  controller.step(1.0/60);controller.pose(1.0/60,float(frame+1)/60)
  var reference:Dictionary=fixture.frames[frame]
  if controller.steps!=reference.steps or state.sw!=reference.sw:failures.append("foot pair state frame %d"%frame)
  for i in 4:
   var p:Array=reference.feet[i];var error=state.feet[i].p.distance_to(Vector3(p[0],p[1],p[2]));maximum=maxf(maximum,error)
   if error>.0001:failures.append("foot %d frame %d"%[i,frame])
  for name in reference.bones:
   var id:String=record.rig.bones[name]["$node"];var pose:Transform3D=scene.source_nodes[id].transform;var expected=scene._transform(reference.bones[name])
   for error in [pose.origin.distance_to(expected.origin),pose.basis.x.distance_to(expected.basis.x),pose.basis.y.distance_to(expected.basis.y),pose.basis.z.distance_to(expected.basis.z)]:
    maximum=maxf(maximum,error);fields+=3
    if error>.0001:failures.append("bone %s frame %d"%[name,frame])
 var report={"failures":failures,"frames":fixture.frames.size(),"bone_fields_compared":fields,"max_transform_or_foot_error":maximum,"steps":controller.steps,"scope":"Original procedural step and IK, flat ground and controlled turning/acceleration; not complete AI"}
 var file=FileAccess.open("res://evidence/hound-pose-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first_failures":failures.slice(0,6),"max_error":maximum,"fields":fields,"steps":controller.steps}));quit(0 if failures.is_empty() else 1)
