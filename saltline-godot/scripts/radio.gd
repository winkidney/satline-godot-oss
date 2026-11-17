class_name SaltlineRadio
extends RefCounted

# Original HUD Y(): typing consumes a frame before the hold timer starts.
signal line_started(text:String)
var queue:Array=[]
var current:Dictionary={}
var cursor=0
var typed=0.0
var remaining=0.0
var text=""
var visible=false

func enqueue(value:String,seconds:float=4.5)->void:
 if not value.is_empty():queue.append({"text":value,"secs":seconds})

func clear()->void:
 queue.clear();current={};visible=false

func update(dt:float)->void:
 if current.is_empty():
  if queue.is_empty():return
  current=queue.pop_front();cursor=0;typed=0;remaining=current.secs;text="";visible=true;line_started.emit(current.text)
 var value:String=current.text
 if cursor<value.length():
  typed+=dt*58
  var count=mini(value.length(),int(floor(typed)))
  if count!=cursor:cursor=count;text=value.left(count)
 else:
  remaining-=dt
  if remaining<=0:
   current={}
   if queue.is_empty():visible=false
