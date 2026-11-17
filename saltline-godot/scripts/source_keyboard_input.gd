extends RefCounted

# Original fE physical bindings and the keyboard portion of gE.v(device, action, down).
const ACTIONS={KEY_W:"forward",KEY_S:"back",KEY_A:"left",KEY_D:"right",KEY_SPACE:"jump",KEY_SHIFT:"sprint",KEY_C:"crouch",KEY_CTRL:"crouch",KEY_R:"reload",KEY_E:"interact",KEY_F:"melee",KEY_V:"melee",KEY_ESCAPE:"pause",KEY_P:"pause",KEY_Q:"swap",KEY_1:"weapon1",KEY_2:"weapon2",KEY_KP_1:"weapon1",KEY_KP_2:"weapon2",KEY_ENTER:"fire",KEY_KP_ENTER:"fire",KEY_LEFT:"turnL",KEY_RIGHT:"turnR",KEY_UP:"turnU",KEY_DOWN:"turnD",KEY_J:"turnL",KEY_L:"turnR",KEY_I:"turnU",KEY_K:"turnD"}
var held={}
var other_held:Callable

func key(code:int,pressed:bool,repeat:bool=false)->bool:
 var action=ACTIONS.get(code,"")
 if action.is_empty() or (pressed and repeat):return false
 if pressed:
  if held.has(action):return false
  held[action]=true;return not other_held.is_valid() or not other_held.call(action)
 held.erase(action);return false

func down(action:String)->bool:return held.has(action)
func clear()->void:held.clear()
func turning()->Vector2i:return Vector2i(int(down("turnR"))-int(down("turnL")),int(down("turnD"))-int(down("turnU")))
