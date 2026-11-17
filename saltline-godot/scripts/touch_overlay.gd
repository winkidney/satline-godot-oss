extends Control
var input
var prompt=false
var font:Font=preload("res://assets/fonts/barlow-condensed-600.ttf")
const BUTTONS={"fire":[20,62,86,"FIRE"],"ads":[120,34,60,"AIM"],"reload":[108,126,54,"RLD"],"swap":[92,196,54,"SWAP"],"jump":[20,164,60,"JUMP"],"interact":[186,96,68,"USE"],"pause":[12,12,42,"II"]}
func rect(action:String)->Rect2:
 var b=BUTTONS[action];return Rect2(size.x-b[0]-b[2],b[1] if action=="pause" else size.y-b[1]-b[2],b[2],b[2])
func hit(point:Vector2)->String:
 for action in BUTTONS:
  if action=="interact" and not prompt:continue
  # DOM buttons use a rectangular hit region even with a circular border.
  if rect(action).has_point(point):return action
 return ""
func _draw()->void:
 if input==null:return
 if input.stick_id>=0:
  var center=Vector2(input.origin[0],input.origin[1]);var nub=center+Vector2(input.move[0],-input.move[1])*58
  draw_circle(center,58,Color(.043,.051,.059,.18));draw_arc(center,58,0,TAU,64,Color(.91,.89,.85,.5),1.5,true)
  draw_circle(nub,24,Color(.91,.89,.85,.3));draw_arc(nub,24,0,TAU,40,Color(.91,.89,.85,.7),1.5,true)
 for action in BUTTONS:
  if action=="interact" and not prompt:continue
  var box=rect(action);var active=input.ads if action=="ads" else input.down(action)
  var color=Color("ffb347") if active or action=="interact" else Color("e8e4da")
  var fill=Color(1,.702,.278,.32) if active else Color(.043,.051,.059,.38)
  if action=="pause":draw_rect(box,fill);draw_rect(box,color,false,1.5)
  else:draw_circle(box.get_center(),box.size.x*.5,fill);draw_arc(box.get_center(),box.size.x*.5,0,TAU,64,Color(color,.55 if not active else 1),1.5,true)
  var text=BUTTONS[action][3];var px=14 if action=="fire" else 10 if action=="swap" else 12
  var extent=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px)
  draw_string(font,box.get_center()+Vector2(-extent.x*.5,(font.get_ascent(px)-font.get_descent(px))*.5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)
