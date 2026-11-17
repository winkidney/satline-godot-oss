extends RefCounted
signal quality_auto(name:String)

const PRESETS={
 "test":{"name":"test","scale":1.0,"msaa":0,"shadow":1024,"tex":256,"volSteps":10,"ao":true,"planar":.5,"bloom":true,"motionBlur":false,"rain":.4},
 "low":{"name":"low","scale":.7,"msaa":0,"shadow":2048,"tex":512,"volSteps":12,"ao":false,"planar":0.0,"bloom":true,"motionBlur":false,"rain":.5},
 "medium":{"name":"medium","scale":.85,"msaa":2,"shadow":2048,"tex":1024,"volSteps":16,"ao":true,"planar":.5,"bloom":true,"motionBlur":false,"rain":.8},
 "high":{"name":"high","scale":1.0,"msaa":4,"shadow":4096,"tex":1024,"volSteps":24,"ao":true,"planar":.5,"bloom":true,"motionBlur":true,"rain":1.0},
 "ultra":{"name":"ultra","scale":1.0,"msaa":4,"shadow":4096,"tex":2048,"volSteps":40,"ao":true,"planar":1.0,"bloom":true,"motionBlur":true,"rain":1.0}}

static func startup_name(saved:String,args:PackedStringArray,source_quality:String)->String:
 # Original settings apply is gated by !params.q and !params.shot.
 for arg in args:
  if arg.begins_with("--cold-quality="):return source_quality
 return source_quality if saved=="auto" else saved

static func resolution(screen:Vector2i,preset:Dictionary,dpr:float=1.0,drs:float=1.0)->Vector2i:
 var ratio=minf(dpr,2.0);var scale=float(preset.scale)*drs
 var cap=float({"low":1000000,"medium":1500000,"high":2300000,"ultra":3700000}.get(preset.name,2300000))
 var pixels=screen.x*ratio*screen.y*ratio*scale*scale
 if pixels>cap:scale*=sqrt(cap/pixels)
 return Vector2i(maxi(16,int(floor(screen.x*ratio*scale+.5))),maxi(16,int(floor(screen.y*ratio*scale+.5))))

var current="high"
var dynamic=preload("res://scripts/dynamic_resolution.gd").new()
var previous_usec=0
var measured_samples=0
var last_frame_ms=0.0
var changes=[]

func configure(engine_args:PackedStringArray,args:PackedStringArray,preview:bool)->void:
 dynamic.state.enabled=not preview and not "--script" in engine_args and not "--dynres=0" in args
 if "--dynres=1" in args:dynamic.state.enabled=true

func frame(game:Node,measured_ms:float=-1)->void:
 var now=Time.get_ticks_usec();var milliseconds=measured_ms if measured_ms>=0 else (now-previous_usec)/1000.0
 var first=previous_usec==0;previous_usec=now
 if first and measured_ms<0:return
 if measured_ms<0 and dynamic.state.enabled:measured_samples+=1;last_frame_ms=milliseconds
 for event in dynamic.sample(milliseconds,current,game.post_pipeline!=null):
  changes.append(event.duplicate(true))
  if changes.size()>64:changes.pop_front()
  if event.kind=="quality":apply(game,event.name)
  elif event.kind=="resize":game.post_pipeline.dynamic_scale=dynamic.state.scale;game.post_pipeline._resize()
  else:quality_auto.emit(event.name)

func apply(game:Node,name:String)->void:
 if not PRESETS.has(name):return
 var preset=PRESETS[name];current=name
 game.post_pipeline.dynamic_scale=dynamic.state.scale;game.post_pipeline.set_quality(preset)
 game.game_ui.effective_quality=name
 game.sun_shadow_pass.set_resolution(int(preset.shadow))
 game.sun_shadow_pass.every_frame=name=="ultra"
 game.source_sun_service.bound_materials.clear();game.source_sun_service.update()
 game.planar_reflection.quality_scale=float(preset.planar)
 game.planar_reflection.render_size=game.post_pipeline.world_port.size
 game.planar_reflection.update(game.camera)
