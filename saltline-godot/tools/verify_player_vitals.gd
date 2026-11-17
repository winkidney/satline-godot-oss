extends SceneTree
var hits=0
var deaths=0
var maximum=0.0
func close(a:Variant,b:Variant)->bool:
 if a is Array:
  for i in a.size():
   if not close(a[i],b[i]):return false
  return true
 if a is float or a is int:
  var error=absf(float(a)-float(b));maximum=maxf(maximum,error);return error<.0001
 return a==b
func array(vector:Vector3)->Array:return [vector.x,vector.y,vector.z]
func _initialize()->void:
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/prepared/scene.json"))
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/player-vitals-reference.json"))
 var player=SaltlinePlayer.new(data.modules.player,SaltlinePhysics.new({"boxes":[],"bounds":{"min":[-40,-50,-32],"max":[31,50,30]}}))
 player.pos=Vector3.ZERO;player.eye=Vector3.ZERO;player.yaw=0
 var camera=Camera3D.new();root.add_child(camera);camera.rotation_order=EULER_ORDER_YXZ;camera.fov=74
 player.hit.connect(func(_amount,_from):hits+=1);player.died.connect(func():deaths+=1)
 var failures=[];var fields=0
 for frame in reference.frames.size():
  if frame==0:player.damage(20,Vector3(1,0,0))
  if frame==60:player.invulnerable=true;player.damage(40)
  if frame==90:player.invulnerable=false;player.damage(10)
  if frame==150:player.heal(5)
  if frame==360:player.damage(200)
  if player.alive:player.update_vitals(1.0/60)
  else:player.ads=exp(-(frame-360)*.1);player._dead_update(1.0/60,camera)
  var row={"health":player.health,"alive":player.alive,"hurtPulse":player.hurt_pulse,"lowHealth":player.low_health,"sinceHit":player.since_hit,"shake":player.shake,"hits":hits,"deaths":deaths,"position":array(player.pos),"eye":array(player.eye),"camera":array(camera.rotation),"fov":camera.fov,"ads":player.ads,"clock":player.clock,"enabled":player.enabled}
  for key in reference.frames[frame]:
   fields+=1
   if not close(row[key],reference.frames[frame][key]):failures.append("%d %s"%[frame,key])
 player.enabled=false;player.reset({"pos":Vector3(3,.4,-2),"yaw":.7},camera)
 var reset={"health":player.health,"alive":player.alive,"hurtPulse":player.hurt_pulse,"lowHealth":player.low_health,"sinceHit":player.since_hit,"shake":player.shake,"hits":hits,"deaths":deaths,"position":array(player.pos),"eye":array(player.eye),"camera":array(camera.rotation),"fov":camera.fov,"ads":player.ads,"clock":player.clock,"enabled":player.enabled}
 for key in reference.reset:
  fields+=1
  if not close(reset[key],reference.reset[key]):failures.append("reset "+key)
 var report={"failures":failures,"frames":reference.frames.size(),"fields":fields,"maximum_error":maximum,"hits":hits,"deaths":deaths,"scope":reference.scope}
 var file=FileAccess.open("res://evidence/player-vitals-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify({"failures":failures.size(),"first":failures.slice(0,8),"fields":fields,"maximum_error":maximum,"hits":hits,"deaths":deaths}));quit(0 if failures.is_empty() else 1)
