extends RefCounted
# Original reload magazine geometry. Hand-target/pose curves remain separate.
const Math=preload("res://scripts/weapon_motion_math.gd")
var holds:Dictionary
var poses:Dictionary={}
var root_rotations={"rifle":Quaternion.IDENTITY,"pistol":Quaternion.IDENTITY}
func _init(rigs:Dictionary)->void:
 holds={"rifle":rigs.rifle.holds,"pistol":rigs.pistol.holds};reset_all()
func vec(value:Array)->Vector3:return Vector3(value[0],value[1],value[2])
func quat(value:Array)->Quaternion:return Quaternion(value[0],value[1],value[2],value[3]).normalized()
func pose(position:Vector3,rotation:Quaternion=Quaternion.IDENTITY)->Transform3D:return Transform3D(Basis(rotation),position)
func euler(x:float,y:float,z:float)->Quaternion:
 return Basis.from_euler(Vector3(x,y,z),EULER_ORDER_XYZ).get_rotation_quaternion()
func hold(gun:String,name:String)->Transform3D:
 var data:Dictionary=holds[gun][name];return pose(vec(data.p),quat(data.q))
func blend(a:Transform3D,b:Transform3D,weight:float)->Transform3D:
 return pose(a.origin.lerp(b.origin,weight),a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(),weight))
func phase(time:float,start:float,finish:float)->float:return clampf((time-start)/(finish-start),0,1)
func out_quad(value:float)->float:
 var t=clampf(value,0,1);return 1.0-(1.0-t)*(1.0-t)
func sample(table:Array,time:float)->Transform3D:
 var index=0
 while index<table.size()-2 and time>table[index+1][0]:index+=1
 var a=table[index];var b=table[index+1]
 return blend(a[1],b[1],Math.ease((time-a[0])/maxf(1e-4,b[0]-a[0])))
func reset_all()->void:
 for gun in ["rifle","pistol"]:reset(gun)
func reset(gun:String)->void:
 poses[gun]=pose(Vector3(0,-.02,-.0665)) if gun=="rifle" else pose(Vector3(0,-.013,.0387),euler(-.314,0,0))
func update(gun:String,time:float)->void:
 if gun=="rifle":rifle(time)
 else:pistol(time)
func rifle(time:float)->void:
 var rest=pose(Vector3(0,-.02,-.0665));var pinch=hold("rifle","pinch");var carry=hold("rifle","carry")
 var initial=rest*pinch
 var down=pose(initial.origin+Vector3(0,-.082,0),initial.basis.get_rotation_quaternion())
 var turn=euler(-.5,0,.25)
 var away=pose(initial.origin+Vector3(-.06,-.36,.13),turn*initial.basis.get_rotation_quaternion())
 var replacement=pose(Vector3(-.05,-.38,.14),turn)
 var rise=pose(rest.origin+replacement.origin,replacement.basis.get_rotation_quaternion())*carry
 if time<.4:poses.rifle=rest
 elif time<.74:
  var clear=out_quad(phase(time,.4,.52));var weight=Math.ease(phase(time,.49,.74))
  var hand=pose(initial.origin.lerp(down.origin,clear).lerp(away.origin,weight),initial.basis.get_rotation_quaternion().slerp(away.basis.get_rotation_quaternion(),weight))
  poses.rifle=hand*pinch.affine_inverse()
 elif time<.86:
  var hand=blend(away,rise,Math.ease(phase(time,.74,.86)))
  poses.rifle=hand*(pinch if time<.8 else carry).affine_inverse()
 elif time<1.15:
  var align=pose(Vector3(-.005,-.09,.006),euler(-.11,0,.07));var insert=pose(Vector3(0,-.076,0))
  var offset=sample([[.86,replacement],[1.1,align],[1.15,insert],[9,insert]],time)
  poses.rifle=pose(rest.origin+offset.origin,offset.basis.get_rotation_quaternion())
 else:
  var distance=0.0
  if time<1.31:distance=.009+(.076-.009)*pow(1.0-phase(time,1.15,1.31),2.2)
  elif time<1.385:distance=.009
  elif time<1.44:
   var t=phase(time,1.385,1.44);distance=minf(.009,(.009+.032)*(1.0-t*t))
  poses.rifle=pose(rest.origin+Vector3(0,-distance,0))
func pistol(time:float)->void:
 var base=Vector3(0,-.013,.0387);var rake=euler(-.314,0,0);var axis=Vector3(0,-.951,.309)
 if time<.48:
  if time<.18:poses.pistol=pose(base,rake)
  else:
   var elapsed=time-.18
   if elapsed<.1366:poses.pistol=pose(base+axis*(4.5*elapsed*elapsed+.3*elapsed),rake)
   else:
    var fall=elapsed-.1366;var gravity=root_rotations.pistol.inverse()*Vector3.DOWN
    poses.pistol=pose(base+axis*(.125+1.53*fall)+gravity*(4.9*fall*fall),rake*Quaternion(Vector3.RIGHT,-2.6*fall))
 else:
  var offset=Transform3D.IDENTITY
  if time<.9:
   var away=pose(Vector3(.1,-.38,.12),euler(-.3,0,.45))
   var align=pose(axis*(.118+.016)+Vector3(-.004,0,.005),euler(-.1,0,.08));var insert=pose(axis*.118)
   offset=sample([[.52,away],[.84,align],[.9,insert],[9,insert]],maxf(time,.52))
  else:
   var distance=0.0
   if time<1.02:distance=.118-.062*out_quad(phase(time,.9,1.02))
   elif time<1.075:distance=.118-.062
   elif time<1.13:
    var t=phase(time,1.075,1.13);distance=minf(.118-.062,(.118-.062+.026)*(1.0-t*t))
   offset=pose(axis*distance)
  poses.pistol=pose(base+offset.origin,offset.basis.get_rotation_quaternion()*rake)
