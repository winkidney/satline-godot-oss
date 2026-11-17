extends SceneTree
var failures=[]
var checks=0
var maximum_error=0.0

func _initialize()->void:call_deferred("run")
func normalized(value:Variant)->Variant:
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Dictionary:
  var result={}
  for key in value:result[key]=normalized(value[key])
  return result
 if value is Array:
  var result=[]
  for item in value:result.append(normalized(item))
  return result
 return value
func compare(actual:Variant,expected:Variant,label:String)->void:
 if expected is Dictionary:
  for key in expected:
   if not actual is Dictionary or not actual.has(key):failures.append(label+" missing "+str(key));continue
   compare(actual[key],expected[key],label+"/"+str(key))
 elif expected is Array:
  if not actual is Array or actual.size()!=expected.size():failures.append(label+" array shape");return
  for i in expected.size():compare(actual[i],expected[i],label+"/"+str(i))
 else:
  checks+=1
  if expected is float or expected is int:
   var error=absf(float(actual)-float(expected));maximum_error=maxf(maximum_error,error)
   if error>.000001:failures.append({"field":label,"actual":actual,"expected":expected})
  elif actual!=expected:failures.append({"field":label,"actual":actual,"expected":expected})
func matrix(t:Transform3D)->Array:return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 await process_frame;RenderingServer.force_draw(false)
 var source=game.source_scene;var records=source.records
 for kind in ["gull","hound"]:
  var captured=source.source.modules.enemies.debug["gulls" if kind=="gull" else "hounds"]
  var fresh:Dictionary={}
  for record in captured:
   if not record.active and int(record.id)==0:fresh=record;break
  assert(not fresh.is_empty(),"Missing original cold pool witness")
  var expected=fresh.duplicate(true);expected.erase("rig");expected.erase("lens")
  for index in game.enemy_manager.pools[kind].size():
   var actor=game.enemy_manager.pools[kind][index];var label=kind+str(index)
   var actual=actor.state.duplicate(true);actual.erase("rig");actual.erase("lens")
   compare(normalized(actual),expected,label)
   compare(matrix(source.source_nodes[actor.state.rig.group["$node"]].transform),records[fresh.rig.group["$node"]].matrix,label+"/group")
   if source.source_nodes[actor.state.rig.group["$node"]].visible:failures.append(label+" cold group visible")
   for bone in fresh.rig.bones:
    var id=actor.state.rig.bones[bone]["$node"];var expected_matrix=records[fresh.rig.bones[bone]["$node"]].matrix
    compare(matrix(source.source_nodes[id].transform),expected_matrix,label+"/bone/"+bone)
    for target in source.bone_targets.get(id,[]):compare(matrix(target[0].get_bone_pose(target[1])),expected_matrix,label+"/native skeleton/"+bone)
   compare(actor.state.rig.group["$node"],captured[index].rig.group["$node"],label+"/rig identity")
   compare(actor.state.lens["$material"],captured[index].lens["$material"],label+"/lens identity")
   compare(normalized(source.materials[actor.state.lens["$material"]].get_shader_parameter("base_color")),normalized(source.materials[fresh.lens["$material"]].get_shader_parameter("base_color")),label+"/cold lens")
   if kind=="gull":compare(actor.flight.rotor_angles,[0,0,0,0],label+"/rotor phase")
 var ai_calls_before_activation=game.enemy_coordinator.rng.calls
 compare(ai_calls_before_activation,0,"cold construction AI random draws")
 var cold_failures=failures.size()
 var gull=game.enemy_manager.spawn("gull",Vector3(0,2,0),{"passive":true,"hover":2,"yaw":.5})
 compare(gull.state.gp,0,"first gull gp");compare(gull.state.gy,0,"first gull gy");compare(gull.state.sweep,0,"first gull sweep");compare(gull.flight.rotor_angles,[0,0,0,0],"first gull rotor phase")
 gull.state.gp=.7;gull.state.gy=.4;gull.flight.rotor_angles[0]=2;gull.pose.bone("rotor0",Basis(Vector3.UP,2))
 game.enemy_manager.retire(gull)
 var reused=game.enemy_manager.spawn("gull",Vector3(1,2,0),{"passive":true,"hover":2,"yaw":.5})
 if reused!=gull:failures.append("gull pool reuse identity")
 compare(reused.state.gp,.7,"reused gp");compare(reused.state.gy,.4,"reused gy");compare(reused.flight.rotor_angles[0],2,"reused rotor phase")
 var hound=game.enemy_manager.spawn("hound",Vector3(-32,0,6),{"passive":true,"yaw":0})
 compare(hound.state.prevSpeed,0,"first hound previous speed");compare(hound.state.scan,0,"first hound scan")
 hound.state.prevSpeed=3.0;hound.state.scan=.8;hound.state.lastPair=0;game.enemy_manager.retire(hound)
 var reused_hound=game.enemy_manager.spawn("hound",Vector3(-32,0,6),{"passive":true,"yaw":0})
 compare(reused_hound.state.prevSpeed,3.0,"reused hound previous speed");compare(reused_hound.state.scan,.8,"reused hound scan");compare(reused_hound.state.lastPair,0,"reused hound gait pair")
 compare(reused_hound.state.sP.x,-.0023296,"reused hound acceleration pitch spring")
 var report={"ai_calls_before_activation":ai_calls_before_activation,"checks":checks,"cold_failures":cold_failures,"maximum_error":maximum_error,"failures":failures,"scope":"Actual Main cold pool before first activation vs original unactivated same-type record and local bone/group/material witness. Per-instance rig/lens identities, native Skeleton3D poses and18 pool members checked; first activation and dirty-state reuse checked. Reuse preserves gp/gy/rotor history instead of cold-resetting each spawn."}
 var path="res://evidence/enemy-cold-pool-before-fix.json" if "--before" in OS.get_cmdline_user_args() else "res://evidence/enemy-cold-pool-verification.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify({"checks":checks,"cold_failures":cold_failures,"failure_count":failures.size(),"first_failures":failures.slice(0,8),"maximum_error":maximum_error}));game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
