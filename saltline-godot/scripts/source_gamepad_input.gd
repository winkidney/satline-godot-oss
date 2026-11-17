extends RefCounted

const ACTIONS={"jump":[0],"crouch":[1,4],"swap":[3,12,13],"melee":[5,11],"ads":[6],"fire":[7],"pause":[9],"weapon1":[14],"weapon2":[15]}
const UI={0:"accept",1:"back",9:"start",12:"up",13:"down",14:"left",15:"right"}
var held={}
var pressed={}
var ui=[]
var move=[0.0,0.0]
var look=[0.0,0.0]
var previous_buttons=PackedByteArray()
var connected=false
var device="kbm"
var acceleration=0.0
var sprint_latch=false
var context=""
var menu_vertical=0
var menu_repeat=0.0
var menu_horizontal=0
var assist=1.0
var assist_time=0.0
var assist_target=1.0
var buttons=[]

func _init()->void:previous_buttons.resize(20)
static func deadzone(value:float)->float:
 var magnitude=absf(value)
 return 0.0 if magnitude<.14 else signf(value)*(magnitude-.14)/(1-.14)
func button(index:int)->bool:
 if index>=buttons.size() or buttons[index]==null:return false
 return bool(buttons[index].get("pressed",false)) or float(buttons[index].get("value",0))>.35
func _ui(action:String)->void:
 if not ui.has(action):ui.append(action)
func _action(action:String,on:bool,external:Array)->void:
 if on:
  if held.has(action):return
  held[action]=true
  if not external.has(action):pressed[action]=true
 else:held.erase(action)
func clear_gameplay()->void:held.clear()
func down(action:String)->bool:return held.has(action)

func poll(pad:Variant,dt:float,gameplay:bool,prompt:bool,now_ms:float,sensitivity:float=1.0,invert_y:bool=false,external:Array=[])->void:
 move=[0.0,0.0];look=[0.0,0.0];ui.clear();pressed.clear()
 if pad==null:
  if connected:
   connected=false;held.clear();sprint_latch=false;context="";previous_buttons.fill(0)
   if device=="pad":device="kbm"
  return
 connected=true;buttons=pad.buttons
 var axes=[]
 for i in 4:axes.append(deadzone(float(pad.axes[i]) if i<pad.axes.size() else 0.0))
 var used=axes[0]!=0 or axes[1]!=0 or axes[2]!=0 or axes[3]!=0
 move=[axes[0],-axes[1]]
 if gameplay:
  var magnitude=minf(1,sqrt(axes[2]*axes[2]+axes[3]*axes[3]))
  acceleration=minf(1,acceleration+dt/.45) if magnitude>.92 else maxf(0,acceleration-dt*6)
  var curve=(.25*magnitude+.75*magnitude*magnitude*magnitude)/magnitude if magnitude>0 else 0.0
  var gain=2.9*(1+(1.75-1)*acceleration)*curve*assist*sensitivity*dt
  look=[axes[2]*gain,axes[3]*gain*.62*(-1 if invert_y else 1)]
  if button(10):sprint_latch=true
  if move[1]<.55:sprint_latch=false
 else:sprint_latch=false
 for i in mini(buttons.size(),20):
  var value=1 if button(i) else 0
  if value!=0 and previous_buttons[i]==0:
   used=true
   if not gameplay and UI.has(i):_ui(UI[i])
  previous_buttons[i]=value
 var x=button(2)
 if x and context.is_empty():context="interact" if prompt else "reload"
 _action("interact",x and context=="interact",external);_action("reload",x and context=="reload",external)
 if not x:context=""
 for action in ACTIONS:
  var on=false
  for index in ACTIONS[action]:on=on or button(index)
  _action(action,on,external)
 _action("sprint",sprint_latch,external)
 if not gameplay:
  var vertical=int(signf(axes[1])) if absf(axes[1])>.6 else 0
  if vertical!=menu_vertical:
   menu_vertical=vertical;menu_repeat=now_ms+380
   if vertical!=0:_ui("up" if vertical<0 else "down")
  elif vertical!=0 and now_ms>menu_repeat:
   menu_repeat=now_ms+170;_ui("up" if vertical<0 else "down")
  var horizontal=int(signf(axes[0])) if absf(axes[0])>.6 else 0
  if horizontal!=menu_horizontal:
   menu_horizontal=horizontal
   if horizontal!=0:_ui("left" if horizontal<0 else "right")
 if used:device="pad"

func update_assist(dt:float,pad_active:bool,target:Callable)->void:
 if not pad_active:assist=1.0;return
 assist_time-=dt
 if assist_time<=0:assist_time=.05;assist_target=.55 if target.call() else 1.0
 assist=assist_target+((assist if assist!=0 else 1.0)-assist_target)*exp(-14*dt)
