class_name SaltlineEnemyHitShapes
extends RefCounted

# Original KS: nearest nonnegative sphere entry, with a strict current-hit bound.
static func sphere(origin:Vector3,direction:Vector3,center:Vector3,radius:float,limit:float,hit:Dictionary)->bool:
 var x=float(origin.x)-float(center.x);var y=float(origin.y)-float(center.y);var z=float(origin.z)-float(center.z)
 var projection=x*direction.x+y*direction.y+z*direction.z
 var discriminant=projection*projection-(x*x+y*y+z*z-radius*radius)
 if discriminant<0:return false
 var distance=-projection-sqrt(discriminant)
 if distance<0 or distance>limit or distance>=hit.dist:return false
 hit.dist=distance;hit.point=origin+direction*distance;hit.normal=(hit.point-center).normalized()
 return true

# Original ZS uses a closest-axis sphere, rather than an analytic capsule intersection.
static func capsule(origin:Vector3,direction:Vector3,start:Vector3,end:Vector3,radius:float,limit:float,hit:Dictionary)->bool:
 var ax=float(end.x)-float(start.x);var ay=float(end.y)-float(start.y);var az=float(end.z)-float(start.z)
 var ox=float(origin.x)-float(start.x);var oy=float(origin.y)-float(start.y);var oz=float(origin.z)-float(start.z)
 var length_squared=ax*ax+ay*ay+az*az;var along=ax*direction.x+ay*direction.y+az*direction.z
 var projected=ax*ox+ay*oy+az*oz;var ray_offset=direction.x*ox+direction.y*oy+direction.z*oz
 var denominator=length_squared-along*along
 var fraction=clampf((projected-along*ray_offset)/denominator,0,1) if denominator>1e-8 else 0.0
 var center=Vector3(start.x+ax*fraction,start.y+ay*fraction,start.z+az*fraction)
 return sphere(origin,direction,center,radius,limit,hit)

static func hound(state:Dictionary,origin:Vector3,direction:Vector3,limit:float,hit:Dictionary)->bool:
 var found=false
 if sphere(origin,direction,state.headPos,.155,limit,hit):hit.part="weak";hit.enemy=state;found=true
 var forward=Vector3(sin(state.yaw),0,cos(state.yaw))
 var height=state.pos.y+.72+state.sY.x-state.crouch
 var start:Vector3=state.pos-forward*.45;var end:Vector3=state.pos+forward*.47
 start.y=height+.03;end.y=start.y
 if capsule(origin,direction,start,end,.27,limit,hit):hit.part="body";hit.enemy=state;found=true
 start.y=state.pos.y+(height-state.pos.y)*.45;end.y=start.y
 if capsule(origin,direction,start,end,.25,limit,hit):hit.part="body";hit.enemy=state;found=true
 return found

static func gull(state:Dictionary,origin:Vector3,direction:Vector3,limit:float,hit:Dictionary)->bool:
 var x=float(origin.x)-state.pos.x;var y=(float(origin.y)-state.pos.y+.03)*2.3;var z=float(origin.z)-state.pos.z
 var dx=float(direction.x);var dy=float(direction.y)*2.3;var dz=float(direction.z)
 var length_squared=dx*dx+dy*dy+dz*dz;var projection=x*dx+y*dy+z*dz
 var discriminant=projection*projection-length_squared*(x*x+y*y+z*z-.25)
 if discriminant<0:return false
 var distance=(-projection-sqrt(discriminant))/length_squared
 if distance<0 or distance>limit or distance>=hit.dist:return false
 hit.dist=distance;hit.part="body";hit.enemy=state;hit.point=origin+direction*distance
 var normal:Vector3=hit.point-state.pos;normal.y*=2.3;hit.normal=normal.normalized();return true
