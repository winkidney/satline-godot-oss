class_name SaltlineCombat
extends RefCounted

signal enemy_killed(actor:Variant)
signal impact(hit:Dictionary)
signal hit_enemy(enemy:Variant,part:String,killed:bool,weak:bool)
var physics:SaltlinePhysics
var player:Variant
var enemies:Array=[]
var registered:Array=[]
var stats={"shots":0,"hits":0,"kills":0}

func _init(collision:SaltlinePhysics,avatar:Variant)->void:
 physics=collision;player=avatar

func register_actor(actor:Variant,append_to_list:bool=true)->void:
 if append_to_list:enemies.append(actor)
 registered.append(actor);actor.killed.connect(_enemy_killed)

func _enemy_killed(actor:Variant)->void:stats.kills+=1;enemy_killed.emit(actor)

func reset_stats()->void:stats={"shots":0,"hits":0,"kills":0}

func raycast(origin:Vector3,direction:Vector3,limit:float)->Dictionary:
 var hit={"dist":INF,"point":Vector3.ZERO,"normal":Vector3.ZERO,"enemy":null,"part":"body"}
 for actor in enemies:
  var state:Dictionary=actor.state
  if not state.alive:continue
  var offset:Vector3=state.pos-origin;offset.y+=.6 if state.type=="hound" else 0
  var projection=offset.dot(direction)
  if projection< -1.5 or projection>limit+1.5 or offset.length_squared()-projection*projection>1.7:continue
  actor.raycast(origin,direction,limit,hit)
 return hit if hit.enemy!=null else {}

func player_shot(origin:Vector3,direction:Vector3,damage:float=28,range_limit:float=300)->Dictionary:
 stats.shots+=1
 var world_hit=physics.raycast(origin,direction,range_limit)
 var enemy_hit=raycast(origin,direction,float(world_hit.dist) if not world_hit.is_empty() else range_limit)
 if not enemy_hit.is_empty():
  stats.hits+=1
  var actor=enemy_hit.actor;var weak=enemy_hit.part=="weak"
  var dead=actor.damage(damage*(2.2 if weak else 1),enemy_hit.point,direction,enemy_hit.part)
  var hit={"point":enemy_hit.point,"normal":enemy_hit.normal,"dist":enemy_hit.dist,"surface":"enemy","enemy":actor,"part":enemy_hit.part,"dir":direction,"from":"player","killed":dead}
  impact.emit(hit);hit_enemy.emit(actor,enemy_hit.part,dead,weak);return hit
 if not world_hit.is_empty():
  var hit={"point":world_hit.point,"normal":world_hit.normal,"dist":world_hit.dist,"surface":world_hit.surface,"enemy":null,"dir":direction,"from":"player","box":world_hit.get("box",{})}
  impact.emit(hit);return hit
 return {}

# Original enemyShot tests the closest projected point against fixed horizontal/vertical limits.
func enemy_shot(origin:Vector3,direction:Vector3,damage:float=6,range_limit:float=200)->bool:
 var world_hit=physics.raycast(origin,direction,range_limit)
 var limit=float(world_hit.dist) if not world_hit.is_empty() else range_limit
 if player!=null and player.alive:
  var projection=(player.pos+Vector3.UP-origin).dot(direction)
  if projection>0 and projection<limit:
   var point=origin+direction*projection
   if Vector2(point.x-player.pos.x,point.z-player.pos.z).length()<.38 and absf(point.y-(player.pos.y+.95))<.95:
    player.damage(damage,origin);return true
 if not world_hit.is_empty():
  impact.emit({"point":world_hit.point,"normal":world_hit.normal,"dist":world_hit.dist,"surface":world_hit.surface,"enemy":null,"dir":direction,"from":"enemy","box":world_hit.get("box",{})})
 return false

func explode(position:Vector3,radius:float=5,damage:float=80,source:String="player")->void:
 for actor in enemies:
  if not actor.state.alive:continue
  var distance=actor.state.pos.distance_to(position)
  if distance<radius and physics.line_of_sight(position,actor.state.pos+Vector3(0,.5,0)):
   actor.damage(damage*(1-distance/radius),actor.state.pos,(actor.state.pos-position).normalized(),"body")
 if player!=null and player.alive:
  var target:Vector3=player.pos+Vector3.UP;var distance=target.distance_to(position)
  if distance<radius and physics.line_of_sight(position,target):player.damage(damage*.5*(1-distance/radius),position)
 if source=="explosive":stats.blasts=stats.get("blasts",0)+1

func dispose()->void:
 for actor in registered:
  if actor.killed.is_connected(_enemy_killed):actor.killed.disconnect(_enemy_killed)
 enemies.clear();registered.clear()
