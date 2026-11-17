extends RefCounted
# Browser gE touch state. Double arrays preserve JS arithmetic until player input.
var enabled=false
var stick_id=-1
var look_id=-1
var fire_id=-1
var origin=[0.0,0.0]
var last_look=[0.0,0.0]
var last_fire=[0.0,0.0]
var move=[0.0,0.0]
var look=[0.0,0.0]
var held={}
var pressed={}
var ads=false
func clear()->void:
 held.clear();ads=false;stick_id=-1;look_id=-1;fire_id=-1;move=[0.0,0.0]
func down(action:String)->bool:return bool(held.get(action,false))
func drag(dx:float,dy:float,sensitivity:float,invert:bool)->void:
 look[0]+=dx*.0052*sensitivity;look[1]+=dy*.0052*sensitivity*(-1 if invert else 1)
func start(id:int,x:float,y:float,width:float,gameplay:bool)->void:
 enabled=true
 if not gameplay:return
 if x<width*.45 and stick_id<0:stick_id=id;origin=[x,y];move=[0.0,0.0]
 elif look_id<0:look_id=id;last_look=[x,y]
func motion(id:int,x:float,y:float,sensitivity:float=1,invert:bool=false)->void:
 if id==stick_id:
  var dx=x-origin[0];var dy=y-origin[1];var length=sqrt(dx*dx+dy*dy)
  if length>58:dx*=58/length;dy*=58/length
  move=[dx/58,-dy/58]
 elif id==look_id:drag(x-last_look[0],y-last_look[1],sensitivity,invert);last_look=[x,y]
 if id==fire_id:drag(x-last_fire[0],y-last_fire[1],sensitivity,invert);last_fire=[x,y]
func finish(id:int)->void:
 if id==stick_id:stick_id=-1;move=[0.0,0.0]
 elif id==look_id:look_id=-1
func button(action:String,id:int,on:bool,x:float=0,y:float=0,external:Array=[])->void:
 enabled=true
 if action=="ads":
  if on:ads=not ads
  return
 if on:
  if action=="fire":fire_id=id;last_fire=[x,y]
  if not down(action) and not external.has(action):pressed[action]=true
  held[action]=true
 else:
  if action=="fire":
   if id!=fire_id:return
   fire_id=-1
  held.erase(action)
func sprint()->bool:return stick_id>=0 and sqrt(move[0]*move[0]+move[1]*move[1])>.93 and move[1]>.8
func end_frame()->void:pressed.clear();look=[0.0,0.0]
