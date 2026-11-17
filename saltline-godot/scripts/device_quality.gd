extends RefCounted
# Original UM predicate, separated from the native device descriptor adapter.
static func choose(requested:String,user_agent:String,touch_points:int,screen:Vector2i,renderer:String)->String:
 if requested in ["test","low","medium","high","ultra"]:return requested
 var mobile=RegEx.create_from_string("(?i)Android|iPhone|iPad|Mobile")
 if mobile.search(user_agent)!=null or (touch_points>1 and mini(screen.x,screen.y)<900):return "low"
 var weak=RegEx.create_from_string("(?i)SwiftShader|llvmpipe|Software|Mali|Adreno|PowerVR")
 if weak.search(renderer)!=null:return "medium"
 var text=renderer.to_lower()
 return "medium" if "intel" in text and not "arc" in text else "high"
static func native_user_agent(os_name:String)->String:
 return "iPhone" if os_name=="iOS" else os_name
static func native_descriptor()->Dictionary:
 # Desktop Godot exposes no browser maxTouchPoints; leave unknown at zero.
 var size=Vector2i.ZERO if DisplayServer.get_name()=="headless" else DisplayServer.screen_get_size()
 return {"user_agent":native_user_agent(OS.get_name()),"touch_points":0,"screen":[size.x,size.y],"renderer":RenderingServer.get_video_adapter_name(),"touch_points_known":false}
static func detect()->Dictionary:
 var info=native_descriptor()
 info.quality=choose("",info.user_agent,info.touch_points,Vector2i(info.screen[0],info.screen[1]),info.renderer)
 return info
