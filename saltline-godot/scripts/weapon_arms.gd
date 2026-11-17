extends RefCounted
# vS/Fh live normal and death-drop pipeline. Public attach flow remains separate.
var targeter
var blend
var models={}
var bone_names=[]
var live=false
var steps=0
var solver_inputs={}
var relaxed=[]
var drop_steps=0
func _init(rigs:Dictionary)->void:
 var config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-arm-pose-config.json"))
 relaxed=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-reload-hand-poses.json")).relaxed
 bone_names=config.bone_names
 targeter=preload("res://scripts/weapon_arm_targets.gd").new(rigs,JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/weapon-arm-config.json")))
 blend=preload("res://scripts/weapon_arm_blend.gd").new()
 models={"r":preload("res://scripts/weapon_arm_pose.gd").new(config),"l":preload("res://scripts/weapon_arm_pose.gd").new(config,true)}
func shot(gun:String)->void:
 models.r.impulse(.55 if gun=="rifle" else .8)
 models.l.impulse(.35 if gun=="rifle" else .6)
func reload_impulse()->void:models.l.impulse(1.0)
func reset()->void:
 targeter.reset();blend.restore();blend.snap()
 # Original normal reset does not replace Fh spring/history instances.
func step(dt:float,weapon,root:Transform3D)->void:
 if blend.drop_time>=0:return
 var targets=targeter.update(weapon.current,dt,weapon.motion_state,weapon.parts_motion.states[weapon.current].finger,weapon.reload_hand.targets[weapon.current],weapon.reload_hand.thumb_weight)
 solver_inputs=blend.update(dt,targets,{"p":root.origin,"q":root.basis.get_rotation_quaternion()})
 _solve(dt,solver_inputs)
 live=true;steps+=1
func _solve(dt:float,inputs:Dictionary)->void:
 for side in inputs:
  var input=inputs[side];var model=models[side];var q:Quaternion=input.q
  model.set_fingers(input.pose);model.set_trigger(input.trig)
  model.solve([input.sh.x,input.sh.y,input.sh.z],[input.p.x,input.p.y,input.p.z],[q.x,q.y,q.z,q.w],[input.pole.x,input.pole.y,input.pole.z],input.lean)
  model.update(dt)


func start_drop(random:Callable)->void:blend.start_drop(random)
func drop_step(dt:float)->void:
 var changed=blend.drop_update(dt,relaxed)
 solver_inputs.merge(changed,true)
 _solve(dt,changed)
 drop_steps+=1

func set_visible(value:bool)->void:
 blend.visible=value
 if blend.drop_time<0:
  for side in ["r","l"]:blend.group_visible[side]=value
