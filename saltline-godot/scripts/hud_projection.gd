class_name SaltlineHudProjection
extends RefCounted

static func js_round(value:float)->int:return int(floor(value+.5))

static func heading(yaw:float)->float:return fposmod(-rad_to_deg(yaw),360)

static func tape_offset(yaw:float,width:float)->float:return js_round((width*.5-(heading(yaw)+90)*4)*2)*.5

static func crosshair(ads:float,alive:bool,state:String,spread:float,fov:float,height:float,sprinting:bool)->Dictionary:
 var visible=ads<=.6 and alive and state!="reloading_hidden"
 var gap=(tan(spread)/tan(deg_to_rad(fov)*.5))*height*.5+4+(10 if sprinting else 0)
 return {"visible":visible,"gap":js_round(clampf(gap,4,70)*2)*.5}

static func marker(position:Vector3,kind:String,player_pos:Vector3,yaw:float,view:Transform3D,fov:float,near:float,far:float,size:Vector2,compass_width:float=420)->Dictionary:
 var dx=position.x-player_pos.x;var dz=position.z-player_pos.z
 var distance=js_round(Vector2(dx,dz).length())
 var relative=fposmod(rad_to_deg(atan2(dx,-dz))-heading(yaw)+540,360)-180
 var limit=compass_width*.5-14
 var compass=js_round(clampf(relative*4,-limit,limit))
 var local=view.affine_inverse()*(position+Vector3(0,1.2 if kind=="extract" else 1.9,0))
 var focal=1/tan(deg_to_rad(fov)*.5)
 var divisor=-local.z
 if divisor==0:divisor=1e-20
 # Use the original OpenGL projection depth for its ce.z > 1 test.
 var x=local.x*focal/(size.x/size.y)/divisor
 var y=local.y*focal/divisor
 var z=((far+near)/(near-far)*local.z+2*far*near/(near-far))/divisor
 var offscreen=false
 if z>1:offscreen=true;x=-x;y=-y
 if offscreen or absf(x)>.9 or absf(y)>.82:
  offscreen=true
  var scale=maxf(maxf(absf(x)/.9,absf(y)/.82),.001)
  x/=scale;y/=scale
  if z>1:
   var edge=maxf(absf(x)/.9,absf(y)/.82)
   if edge<.999 and edge>0:x/=edge;y/=edge
 return {"distance":distance,"compass":compass,"edge":absf(compass)>=limit,"x":js_round((x*.5+.5)*size.x),"y":js_round((-y*.5+.5)*size.y),"offscreen":offscreen,"near":distance<3,"dim":not offscreen and Vector2(x,y*.6).length()<.16}
