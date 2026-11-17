class_name SaltlinePhysics
extends RefCounted

# Direct port of the active HTML moveCapsule, source lines 40080-40186.
var boxes:Array=[]
var bounds:Dictionary
const STEP=0.42
const RADIUS=0.32

func _init(data:Dictionary)->void:
 bounds=data.bounds
 for entry in data.boxes:
  var box:Dictionary=entry.duplicate()
  box.min=Vector3(entry.min[0],entry.min[1],entry.min[2])
  box.max=Vector3(entry.max[0],entry.max[1],entry.max[2])
  boxes.append(box)

func can_stand(pos:Vector3,crouch_height:float,stand_height:float)->bool:
 var radius=RADIUS*.9
 for b in boxes:
  if b.bulletOnly:continue
  if pos.x+radius<b.min.x or pos.x-radius>b.max.x or pos.z+radius<b.min.z or pos.z-radius>b.max.z:continue
  if b.min.y<pos.y+stand_height and b.max.y>pos.y+crouch_height-.05:return false
 return true

func move_capsule(pos:Vector3,vel:Vector3,dt:float,height:float,grounded:bool)->Dictionary:
 var result={"on_ground":false,"hit_wall":false,"hit_ceil":false,"surface":"concrete"}
 var delta=Vector2(vel.x,vel.z)*dt
 var steps=maxi(1,int(ceil(delta.length()/(RADIUS*.6))))
 var old_y=pos.y
 for substep in steps:
  pos.x+=delta.x/steps;pos.z+=delta.y/steps
  for iteration in 3:
   var collided=false
   for b in boxes:
    if b.bulletOnly or b.max.y<=pos.y+(STEP if grounded else .08) or b.min.y>=pos.y+height:continue
    var offset=Vector2(pos.x-clampf(pos.x,b.min.x,b.max.x),pos.z-clampf(pos.z,b.min.z,b.max.z))
    var distance_squared=offset.length_squared()
    if distance_squared>=RADIUS*RADIUS:continue
    if distance_squared>1e-10:
     var distance=sqrt(distance_squared);offset/=distance
     pos.x+=offset.x*(RADIUS-distance);pos.z+=offset.y*(RADIUS-distance)
     var inward=vel.x*offset.x+vel.z*offset.y
     if inward<0:vel.x-=offset.x*inward;vel.z-=offset.y*inward
    else:
     var gaps=[pos.x-b.min.x,b.max.x-pos.x,pos.z-b.min.z,b.max.z-pos.z]
     var nearest=gaps.min()
     if nearest==gaps[0]:pos.x=b.min.x-RADIUS;vel.x=minf(vel.x,0)
     elif nearest==gaps[1]:pos.x=b.max.x+RADIUS;vel.x=maxf(vel.x,0)
     elif nearest==gaps[2]:pos.z=b.min.z-RADIUS;vel.z=minf(vel.z,0)
     else:pos.z=b.max.z+RADIUS;vel.z=maxf(vel.z,0)
    collided=true;result.hit_wall=true
   if not collided:break
 var candidate_y=pos.y+vel.y*dt
 var support_radius=RADIUS*.7
 var floor_y=0.0 if pos.x<=30+support_radius else -50.0
 var ceiling_y=INF
 var floor_limit=old_y+(STEP if grounded else .08)+.0001
 for b in boxes:
  if b.bulletOnly or pos.x+support_radius<b.min.x or pos.x-support_radius>b.max.x or pos.z+support_radius<b.min.z or pos.z-support_radius>b.max.z:continue
  if b.max.y<=floor_limit and b.max.y>floor_y:floor_y=b.max.y;result.surface=b.surface
  if b.min.y>=old_y+height-.05 and b.min.y<ceiling_y:ceiling_y=b.min.y
 if vel.y>0 and candidate_y+height>ceiling_y:
  pos.y=ceiling_y-height;vel.y=0;result.hit_ceil=true
 elif candidate_y<=floor_y or (grounded and vel.y<=0 and candidate_y-floor_y<STEP):
  pos.y=floor_y;vel.y=maxf(0,vel.y);result.on_ground=true
 else:pos.y=candidate_y
 result.position=pos;result.velocity=vel
 return result

func raycast(origin:Vector3,direction:Vector3,max_distance:float)->Dictionary:
 var closest=max_distance
 var result:Dictionary={}
 if direction.y< -1e-6:
  var ground_distance=-origin.y/direction.y
  if ground_distance>0 and ground_distance<closest:
   var ground_point=origin+direction*ground_distance
   if ground_point.x<=30:
    closest=ground_distance;result={"point":ground_point,"normal":Vector3.UP,"surface":"concrete","box":null}
   else:
    var water_distance=(-1.6-origin.y)/direction.y
    if water_distance>0 and water_distance<closest:
     closest=water_distance;result={"point":origin+direction*water_distance,"normal":Vector3.UP,"surface":"water","box":null}
 for box in boxes:
  if box.playerOnly:continue
  var near_distance=0.0;var far_distance=closest;var axis=-1;var sign_value=0.0;var intersects=true
  for component in 3:
   if direction[component]==0:
    if origin[component]<box.min[component] or origin[component]>box.max[component]:intersects=false;break
    continue
   var near_plane=(box.min[component]-origin[component])/direction[component]
   var far_plane=(box.max[component]-origin[component])/direction[component]
   var normal_sign=-1.0
   if near_plane>far_plane:
    var swap=near_plane;near_plane=far_plane;far_plane=swap;normal_sign=1
   if near_plane>near_distance:near_distance=near_plane;axis=component;sign_value=normal_sign
   far_distance=minf(far_distance,far_plane)
   if near_distance>far_distance:intersects=false;break
  if intersects and axis>=0:
   closest=near_distance
   var normal=Vector3.ZERO;normal[axis]=sign_value
   result={"point":origin+direction*closest,"normal":normal,"surface":box.surface,"box":box}
 if not result.is_empty():result.dist=closest
 return result

func line_of_sight(origin:Vector3,target:Vector3)->bool:
 var distance=origin.distance_to(target)
 return distance<.0001 or raycast(origin,(target-origin)/distance,distance-.05).is_empty()

func ground_height(x:float,z:float,ceiling:float=50)->float:
 var height=0.0 if x<=30 else -1.6
 for box in boxes:
  if box.bulletOnly:continue
  if x>=box.min.x and x<=box.max.x and z>=box.min.z and z<=box.max.z and box.max.y<=ceiling and box.max.y>height:height=box.max.y
 return height
