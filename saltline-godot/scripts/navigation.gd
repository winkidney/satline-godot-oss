class_name SaltlineNavigation
extends RefCounted

const CELL=.5
const MIN_X=-40.0
const MIN_Z=-32.0
const WIDTH=142
const HEIGHT=124
var physics:SaltlinePhysics
var blocked=PackedByteArray()
var source_box_count=-1
var costs=PackedFloat32Array()
var parents=PackedInt32Array()
var seen=PackedInt32Array()
var closed=PackedInt32Array()
var generation=0
var heap_nodes:Array=[]
var heap_scores:Array=[]
var rng

func _init(collision:SaltlinePhysics,random_stream:Variant=null)->void:
 physics=collision
 rng=random_stream if random_stream!=null else preload("res://scripts/fx_random.gd").new()
 costs.resize(WIDTH*HEIGHT);parents.resize(WIDTH*HEIGHT);seen.resize(WIDTH*HEIGHT);closed.resize(WIDTH*HEIGHT)

func rebuild()->void:
 blocked.resize(WIDTH*HEIGHT);blocked.fill(0);source_box_count=physics.boxes.size()
 for box in physics.boxes:
  if box.noNav or box.bulletOnly or box.max.y<.47 or box.min.y>1.5:continue
  var x0=maxi(0,int(floor((box.min.x-.5-MIN_X)/CELL)))
  var x1=mini(WIDTH-1,int(floor((box.max.x+.5-MIN_X)/CELL)))
  var z0=maxi(0,int(floor((box.min.z-.5-MIN_Z)/CELL)))
  var z1=mini(HEIGHT-1,int(floor((box.max.z+.5-MIN_Z)/CELL)))
  for z in range(z0,z1+1):
   for x in range(x0,x1+1):blocked[z*WIDTH+x]=1
 for z in HEIGHT:
  for x in WIDTH:
   if MIN_X+(x+.5)*CELL>29.5 or x==0 or z==0 or x==WIDTH-1 or z==HEIGHT-1:blocked[z*WIDTH+x]=1

func _ensure()->void:
 if source_box_count!=physics.boxes.size():rebuild()

func cell_index(x:float,z:float)->int:
 var cx=int(floor((x-MIN_X)/CELL));var cz=int(floor((z-MIN_Z)/CELL))
 return -1 if cx<0 or cz<0 or cx>=WIDTH or cz>=HEIGHT else cz*WIDTH+cx

func cell_center(index:int)->Vector3:
 return Vector3(MIN_X+(index%WIDTH+.5)*CELL,0,MIN_Z+(int(index/WIDTH)+.5)*CELL)

func is_walkable(x:float,z:float)->bool:
 _ensure();var index=cell_index(x,z)
 return index>=0 and blocked[index]==0

func _nearest(x:float,z:float)->int:
 var cx=clampi(int(floor((x-MIN_X)/CELL)),0,WIDTH-1);var cz=clampi(int(floor((z-MIN_Z)/CELL)),0,HEIGHT-1)
 if not blocked[cz*WIDTH+cx]:return cz*WIDTH+cx
 for radius in range(1,13):
  var best=-1;var distance=1e9
  for dz in range(-radius,radius+1):
   for dx in range(-radius,radius+1):
    if maxi(absi(dx),absi(dz))!=radius:continue
    var xx=cx+dx;var zz=cz+dz
    if xx<0 or zz<0 or xx>=WIDTH or zz>=HEIGHT or blocked[zz*WIDTH+xx]:continue
    var candidate=dx*dx+dz*dz
    if candidate<distance:distance=candidate;best=zz*WIDTH+xx
  if best>=0:return best
 return -1

func _line(a:int,b:int)->bool:
 var x=a%WIDTH;var z=int(a/WIDTH);var end_x=b%WIDTH;var end_z=int(b/WIDTH)
 var dx=absi(end_x-x);var dz=absi(end_z-z);var sx=1 if x<end_x else -1;var sz=1 if z<end_z else -1;var error=dx-dz
 for i in 600:
  if blocked[z*WIDTH+x]:return false
  if x==end_x and z==end_z:return true
  var twice=2*error
  if twice> -dz and twice<dx:
   if blocked[z*WIDTH+x+sx] or blocked[(z+sz)*WIDTH+x]:return false
   error+=dx-dz;x+=sx;z+=sz
  elif twice> -dz:error-=dz;x+=sx
  else:error+=dx;z+=sz
 return false

func clear_line(start:Vector3,goal:Vector3)->bool:
 _ensure();var a=cell_index(start.x,start.z);var b=cell_index(goal.x,goal.z)
 return a>=0 and b>=0 and _line(a,b)

func random_point(origin:Vector3,radius:float)->Vector3:
 _ensure()
 for i in 24:
  var angle=rng.randf()*6.2832;var distance=sqrt(rng.randf())*radius
  var x=origin.x+cos(angle)*distance;var z=origin.z+sin(angle)*distance
  var index=cell_index(x,z)
  if index>=0 and not blocked[index]:return Vector3(x,0,z)
 var index=_nearest(origin.x,origin.z)
 return cell_center(index) if index>=0 else Vector3(origin.x,0,origin.z)

func _push(node:int,score:float)->void:
 var index=heap_nodes.size();heap_nodes.append(node);heap_scores.append(score)
 while index>0:
  var parent=(index-1)>>1
  if heap_scores[parent]<=score:break
  heap_nodes[index]=heap_nodes[parent];heap_scores[index]=heap_scores[parent];index=parent
 heap_nodes[index]=node;heap_scores[index]=score

func _pop()->int:
 var result:int=heap_nodes[0];var node=heap_nodes.pop_back();var score=heap_scores.pop_back();var size=heap_nodes.size()
 if size:
  var index=0
  while true:
   var child=index*2+1
   if child>=size:break
   if child+1<size and heap_scores[child+1]<heap_scores[child]:child+=1
   if heap_scores[child]>=score:break
   heap_nodes[index]=heap_nodes[child];heap_scores[index]=heap_scores[child];index=child
  heap_nodes[index]=node;heap_scores[index]=score
 return result

func _heuristic(index:int,goal:int)->float:
 var dx=absi(index%WIDTH-goal%WIDTH);var dz=absi(int(index/WIDTH)-int(goal/WIDTH))
 return dx+dz+(1.4142-2)*mini(dx,dz)

func _search(start:int,goal:int)->Variant:
 generation+=1;heap_nodes.clear();heap_scores.clear()
 costs[start]=0;seen[start]=generation;parents[start]=-1;_push(start,_heuristic(start,goal))
 var visited=0
 while not heap_nodes.is_empty():
  var current=_pop()
  if current==goal:break
  if closed[current]==generation:continue
  closed[current]=generation;visited+=1
  if visited>9000:return null
  var x=current%WIDTH;var z=int(current/WIDTH)
  for dz in range(-1,2):
   for dx in range(-1,2):
    if not dx and not dz:continue
    var xx=x+dx;var zz=z+dz
    if xx<0 or zz<0 or xx>=WIDTH or zz>=HEIGHT:continue
    var index=zz*WIDTH+xx
    if blocked[index] or closed[index]==generation or (dx and dz and (blocked[z*WIDTH+xx] or blocked[zz*WIDTH+x])):continue
    var cost=costs[current]+(1.4142 if dx and dz else 1.0)
    if seen[index]!=generation or cost<costs[index]:
     costs[index]=cost;seen[index]=generation;parents[index]=current;_push(index,cost+_heuristic(index,goal))
 if seen[goal]!=generation:return null
 var route=[];var index=goal
 while index!=-1:route.append(index);index=parents[index]
 route.reverse();return route

func find_path(start:Vector3,goal:Vector3)->Variant:
 _ensure();var a=_nearest(start.x,start.z);var b=_nearest(goal.x,goal.z)
 if a<0 or b<0:return null
 if a==b:return [Vector3(goal.x,0,goal.z)]
 var route=_search(a,b)
 if route==null:return null
 var output=[];var cursor=0
 while cursor<route.size()-1:
  var next=cursor+1
  for i in range(route.size()-1,cursor+1,-1):
   if _line(route[cursor],route[i]):next=i;break
  output.append(cell_center(route[next]));cursor=next
 if cell_index(goal.x,goal.z)==b and not output.is_empty():output[-1]=Vector3(goal.x,0,goal.z)
 return output
