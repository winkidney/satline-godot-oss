class_name SaltlineGullPose
extends RefCounted

var scene:SaltlineSourceScene
var state:Dictionary
var bones:Dictionary
var flight:SaltlineGullFlight
var behavior:SaltlineGullBehavior

func _init(source:SaltlineSourceScene,record:Dictionary,movement:SaltlineGullFlight,controller:SaltlineGullBehavior)->void:
 scene=source;state=movement.state;bones=record.rig.bones;flight=movement;behavior=controller
 for i in 4:flight.rotor_angles[i]=scene.source_nodes[bones["rotor%d"%i]["$node"]].rotation.y

func bone(name:String,rotation:Basis,position:Variant=null)->void:
 var id:String=bones[name]["$node"];var transform:Transform3D=scene.source_nodes[id].transform
 transform.basis=rotation
 if position!=null:transform.origin=position
 scene.set_source_transform(id,transform)

func scale_bone(name:String,value:float)->void:
 var id:String=bones[name]["$node"];var transform:Transform3D=scene.source_nodes[id].transform
 transform.basis=transform.basis.orthonormalized().scaled(Vector3.ONE*value);scene.set_source_transform(id,transform)

func activate()->void:
 for i in 4:scale_bone("rotor%d"%i,1)
 scale_bone("lamp",1);bone("body",Basis.IDENTITY)
 var group:Node3D=scene.source_nodes[state.rig.group["$node"]];group.visible=true;group.position=state.pos;group.basis=Basis(Vector3.UP,state.yaw)

func group_pose()->void:
 var group:Node3D=scene.source_nodes[state.rig.group["$node"]]
 group.position=state.pos;group.basis=Basis.from_euler(Vector3(state.pitch,state.yaw,state.roll),EULER_ORDER_YXZ)

func update()->void:
 group_pose()
 var body:Vector3=scene.source_nodes[bones.body["$node"]].position;body.y=flight.body_y;bone("body",Basis.IDENTITY,body)
 for i in 4:bone("rotor%d"%i,Basis(Vector3.UP,flight.rotor_angles[i]))
 scale_bone("strobeR",behavior.strobe_rg);scale_bone("strobeG",behavior.strobe_rg);scale_bone("strobeW",behavior.strobe_w)
 bone("gimbalYaw",Basis(Vector3.UP,state.gy));bone("ball",Basis(Vector3.RIGHT,state.gp-state.pitch));bone("gun",Basis(Vector3.RIGHT,behavior.gun_pitch))
 lens(behavior.lens_color)

func lens(color:Vector3)->void:scene.materials[state.lens["$material"]].set_shader_parameter("base_color",color)
