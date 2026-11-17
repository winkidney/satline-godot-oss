extends Node

signal stage_presented(message:String,progress:float)
signal ready_presented(game:Node)
var game
var cover:Control
var mark
var subtitle
var bar:ColorRect
var fill:ColorRect
var stages=[]
var message="Raising the terminal"
var progress=0.0
var progress_initial=0.0
var progress_clock=0.0
var progress_timing=preload("res://scripts/css_transition_timing.gd").new()
var opacity=preload("res://scripts/css_opacity_transition.gd").new(.6)
var done=false
var done_time=0.0
var standalone=false

func _ready()->void:
 if standalone:return
 var args=OS.get_cmdline_user_args()
 var enabled=true
 for arg in args:
  if arg!="--game" and not arg.begins_with("--cold-quality=") and not arg.begins_with("--dynres="):enabled=false;break
 if not enabled:
  await get_tree().process_frame
  game=load("res://scenes/main.tscn").instantiate();get_tree().root.add_child(game);get_tree().current_scene=game;queue_free();return
 await begin()
 await stage("Waking the renderer",.04)
 game=load("res://scenes/main.tscn").instantiate();game.boot_overlay=self;game.process_mode=Node.PROCESS_MODE_DISABLED;game.visible=false;get_tree().root.add_child(game)
 await game.initialization_complete
 await stage("Waiting for first light",.92)
 game.visible=true;game.process_mode=Node.PROCESS_MODE_INHERIT;get_tree().current_scene=game
 while not game.post_pipeline.combined_depth.is_ready_for(game.post_pipeline.world_port.size):
  await get_tree().process_frame;await RenderingServer.frame_post_draw
 await finish(game)

func begin()->void:
 preload("res://scripts/motion_preference.gd").refresh(DisplayServer.accessibility_should_reduce_animation())
 progress_timing.duration=.25;progress_timing.respects_motion_preference=false;progress_timing.reset(0.0,0.0);opacity.reset(1.0)
 var layer=CanvasLayer.new();layer.layer=100;add_child(layer)
 cover=Control.new();cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(cover)
 var background=ColorRect.new();background.color=Color("0b0d0f");background.mouse_filter=Control.MOUSE_FILTER_IGNORE;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);cover.add_child(background)
 mark=preload("res://scripts/title_premise.gd").new();mark.font_path="res://assets/fonts/big-shoulders-display-900.ttf";mark.text="SALTLINE";mark.tracking_em=.16;mark.line_height_em=1;mark.text_color=Color("e8e4da");cover.add_child(mark)
 subtitle=preload("res://scripts/title_premise.gd").new();subtitle.font_path="res://assets/fonts/ibm-plex-mono-400.ttf";subtitle.tracking_em=.18;subtitle.line_height_em=1.25;subtitle.text_color=Color("8d9aa3");cover.add_child(subtitle)
 bar=ColorRect.new();bar.color=Color("23282c");bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;cover.add_child(bar)
 fill=ColorRect.new();fill.color=Color("ffb347");fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;bar.add_child(fill)
 _layout();await get_tree().process_frame;await RenderingServer.frame_post_draw
 stage_presented.emit(message,0.0)

func finish(scene:Node)->void:
 game=scene
 await stage("Ready",1.0)
 done=true;cover.mouse_filter=Control.MOUSE_FILTER_IGNORE;opacity.set_target(false);ready_presented.emit(game)

func begin_showcase()->void:
 await begin()
 await stage("Waking the renderer",.04)
 await stage("Mixing paint, rust and rain",.12)

func finish_showcase(scene:Node)->void:
 await stage("Waiting for first light",.92)
 scene._process(0.0)
 RenderingServer.force_draw(false)
 while not scene.post_pipeline.combined_depth.is_ready_for(scene.post_pipeline.world_port.size):
  await get_tree().process_frame;RenderingServer.force_draw(false)
 await finish(scene)

func stage(value:String,fraction:float)->void:
 assert(fraction>=progress and fraction<=1,"Boot stages must be monotonic")
 var current=lerpf(progress_initial,float(progress_timing.target),progress_timing.progress(progress_clock))
 progress_initial=current;progress_timing.retarget(fraction,current,progress_clock)
 message=value;progress=fraction;stages.append({"message":value,"progress":fraction});_layout()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 stage_presented.emit(value,fraction)

func _layout()->void:
 if cover==null:return
 var screen=get_viewport().get_visible_rect().size;var pixels=clampf(screen.x*.09,40,96)
 mark.layout(screen.x-32,pixels);var mark_width=mark.width_of(mark.text)
 subtitle.text=message.to_upper();subtitle.layout(screen.x-32,12);subtitle.size.x=minf(screen.x-32,subtitle.width_of(subtitle.text))
 var height=pixels+subtitle.layout_height+30;var top=(screen.y-height)*.5
 mark.position=Vector2((screen.x-mark_width+mark.tracking)*.5,top)
 subtitle.position=Vector2((screen.x-subtitle.size.x)*.5,top+pixels+14)
 bar.position=Vector2((screen.x-minf(320,screen.x*.7))*.5,top+pixels+subtitle.layout_height+28);bar.size=Vector2(minf(320,screen.x*.7),2)

func _process(dt:float)->void:
 if cover==null:return
 preload("res://scripts/motion_preference.gd").refresh(DisplayServer.accessibility_should_reduce_animation())
 progress_clock+=dt;_layout()
 fill.size=Vector2(bar.size.x*lerpf(progress_initial,float(progress_timing.target),progress_timing.progress(progress_clock)),2)
 cover.modulate.a=opacity.advance(dt)
 if done:
  done_time+=dt
  if done_time>=.7:queue_free()
