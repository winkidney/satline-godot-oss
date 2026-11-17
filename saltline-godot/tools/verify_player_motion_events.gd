extends SceneTree
class CollisionStub extends SaltlinePhysics:
 var row:Dictionary
 var ground_arguments:Array=[]
 var vertical_arguments:Array=[]
 var height_arguments:Array=[]
 func _init(data:Dictionary,entry:Dictionary)->void:super(data);row=entry
 func can_stand(_pos:Vector3,_crouch_height:float,_stand_height:float)->bool:return row.can_stand
 func move_capsule(_pos:Vector3,_vel:Vector3,_dt:float,_height:float,_grounded:bool)->Dictionary:
  ground_arguments.append(_grounded);vertical_arguments.append(_vel.y);height_arguments.append(_height)
  return {"position":Vector3(row.result_pos[0],row.result_pos[1],row.result_pos[2]),"velocity":Vector3(row.result_velocity[0],row.result_velocity[1],row.result_velocity[2]),"on_ground":row.result_ground,"surface":row.surface}
var failures=[]
var comparisons=0
var maximum=0.0
var context=""
func fail(message:String)->void:
 if failures.size()<20:failures.append(context+" "+message)
func compare(actual:Variant,expected:Variant,path:String)->void:
 if actual is Vector3:actual={"x":actual.x,"y":actual.y,"z":actual.z}
 if expected is Dictionary:
  if actual.size()!=expected.size():fail(path+" dictionary size")
  for key in expected:compare(actual[key],expected[key],path+"."+key)
 elif expected is Array:
  if actual.size()!=expected.size():fail(path+" array size");return
  for index in expected.size():compare(actual[index],expected[index],path+"/"+str(index))
 elif expected is bool or expected==null or expected is String:
  comparisons+=1
  if actual!=expected:fail(path+" mismatch")
 else:
  comparisons+=1
  if not is_finite(float(actual)) or not is_finite(float(expected)):fail(path+" non-finite");return
  var error=absf(float(actual)-float(expected));maximum=maxf(maximum,error)
  if error>2e-6:fail(path+" error="+str(error))
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/player-motion-events-reference.json"));var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 for sample in reference.rows:
  var row:Dictionary=sample.input;context=row.name;var physics=CollisionStub.new(data.physics,row)
  var player=load("res://scripts/player.gd").new(data.modules.player,physics);var weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
  player.pos=Vector3(row.pos[0],row.pos[1],row.pos[2]);player.velocity=Vector3(row.velocity[0],row.velocity[1],row.velocity[2]);player.safe_pos=Vector3(row.safe_pos[0],row.safe_pos[1],row.safe_pos[2])
  player.on_ground=row.ground;player.crouching=row.crouch;player.sprinting=row.sprint;player.speed=4.0 if row.sprint else 0.0;player.coyote=row.coyote;player.jump_buffer=row.jump_buffer;player.air_time=row.air_time;player.fall_speed=row.fall_speed;player.stride_phase=row.phase;player.shake=row.shake
  if row.resolved_surface!="":player.surface_resolver=func(_pos,_surface):return row.resolved_surface
  var events=[];var damage=[];var player_ref=weakref(player);var weapon_ref=weakref(weapon)
  player.motion_event.connect(weapon.on_player_motion_event)
  player.motion_event.connect(func(kind,payload):
   var avatar=player_ref.get_ref();var state=weapon_ref.get_ref().motion_state
   events.append({"kind":kind,"payload":payload.duplicate(true),"phase":avatar.stride_phase,"shake":avatar.shake,"flags":{"stepEv":state.stepEv,"jumpEv":state.jumpEv,"landEv":state.landEv}})
  )
  player.hit.connect(func(amount,_from):damage.append(amount))
  var camera=Camera3D.new();root.add_child(camera)
  var input={"move":Vector2(0,1) if row.sprint else Vector2.ZERO,"sprint":row.sprint,"crouch":row.crouch,"ads":false,"fire":false,"jump":row.jump}
  player.update(row.dt,input,camera)
  compare(physics.ground_arguments,[row.ground],"collision prior-ground argument")
  compare(physics.vertical_arguments,[sample.expected.impact],"collision vertical velocity")
  compare(physics.height_arguments,[sample.expected.height],"collision height")
  compare(events,sample.expected.events,"events");compare(damage,sample.expected.damage,"damage");compare(player.stride_phase,sample.expected.phase,"phase")
  compare({"stepEv":weapon.motion_state.stepEv,"jumpEv":weapon.motion_state.jumpEv,"landEv":weapon.motion_state.landEv},sample.expected.flags,"pending flags")
  weapon.reset();compare([weapon.motion_state.stepEv,weapon.motion_state.jumpEv,weapon.motion_state.landEv],[0,0,-1],"reset events")
  player.ground_surface="metal";player.reset({"pos":[-20,0,0],"yaw":0})
  compare(player.ground_surface,"metal","reset preserves source L surface")
  camera.free()
 # Functional bridge check against the actual exported-world collision solver.
 var real_physics=load("res://scripts/source_physics.gd").new(data.physics)
 var real_player=load("res://scripts/player.gd").new(data.modules.player,real_physics);var real_weapon=load("res://scripts/weapon.gd").new(data.modules.weapon)
 var real_events={"jump":0,"land":0,"step":0,"rescued":0}
 real_player.motion_event.connect(real_weapon.on_player_motion_event)
 real_player.motion_event.connect(func(kind,_payload):real_events[kind]+=1)
 var view=Camera3D.new();root.add_child(view)
 var real_input={"move":Vector2.ZERO,"sprint":false,"crouch":false,"ads":false,"fire":false,"jump":false}
 for i in 120:real_player.update(1.0/60,real_input,view)
 real_input.jump=true;real_player.update(1.0/60,real_input,view);real_input.jump=false
 for i in 120:real_player.update(1.0/60,real_input,view)
 real_input.move=Vector2(0,1);real_input.sprint=true
 for i in 120:real_player.update(1.0/60,real_input,view)
 context="exported-world functional"
 if real_events.jump!=1 or real_events.land!=1 or real_events.step<1:fail("expected jump/land/steps "+str(real_events))
 if real_weapon.motion_state.jumpEv!=1 or real_weapon.motion_state.stepEv!=1 or real_weapon.motion_state.landEv<=0:fail("actual physics events not delivered")
 var actual_world={"events":real_events,"landing_speed":real_weapon.motion_state.landEv,"scope":"Functional source-world collision->Player signal->Weapon pending flags; no original full-world trajectory comparison and no D consumption."}
 view.free()
 var report={"actual_world":actual_world,"coverage":reference.coverage,"cases":reference.rows.size(),"comparisons":comparisons,"maximum_error":maximum,"tolerance":2e-6,"failures":failures,"source_sha256":reference.source_sha256,"segments_sha256":reference.segments_sha256,"scope":reference.scope+" Actual native Player.update with controlled collision, signal->production weapon listener, event-time phase/shake and damage. Float32 velocity/position boundary; no full world collision/puddle/step FX or D consumption proof."}
 FileAccess.open("res://evidence/player-motion-events-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
