extends RefCounted
var device_id=-1
var name=""
const BUTTONS={0:JOY_BUTTON_A,1:JOY_BUTTON_B,2:JOY_BUTTON_X,3:JOY_BUTTON_Y,4:JOY_BUTTON_LEFT_SHOULDER,5:JOY_BUTTON_RIGHT_SHOULDER,8:JOY_BUTTON_BACK,9:JOY_BUTTON_START,10:JOY_BUTTON_LEFT_STICK,11:JOY_BUTTON_RIGHT_STICK,12:JOY_BUTTON_DPAD_UP,13:JOY_BUTTON_DPAD_DOWN,14:JOY_BUTTON_DPAD_LEFT,15:JOY_BUTTON_DPAD_RIGHT,16:JOY_BUTTON_GUIDE}
func read()->Variant:
 var devices=Input.get_connected_joypads();device_id=-1
 for id in devices:
  if device_id<0:device_id=id
  if Input.is_joy_known(id):device_id=id;break
 if device_id<0:name="";return null
 name=Input.get_joy_name(device_id)
 var buttons=[]
 for i in 20:buttons.append({"pressed":false,"value":0.0})
 for browser in BUTTONS:
  var on=Input.is_joy_button_pressed(device_id,BUTTONS[browser]);buttons[browser]={"pressed":on,"value":1.0 if on else 0.0}
 buttons[6].value=Input.get_joy_axis(device_id,JOY_AXIS_TRIGGER_LEFT);buttons[7].value=Input.get_joy_axis(device_id,JOY_AXIS_TRIGGER_RIGHT)
 return {"axes":[Input.get_joy_axis(device_id,JOY_AXIS_LEFT_X),Input.get_joy_axis(device_id,JOY_AXIS_LEFT_Y),Input.get_joy_axis(device_id,JOY_AXIS_RIGHT_X),Input.get_joy_axis(device_id,JOY_AXIS_RIGHT_Y)],"buttons":buttons}
