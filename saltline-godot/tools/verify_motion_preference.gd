extends SceneTree
const Policy=preload("res://scripts/motion_preference.gd")
class Status extends "res://scripts/status_hud.gd":
 var cue_alpha=-1.0
 func _right(font:Font,value:String,right:float,y:float,pixels:int,color:Color,tracking:float=0)->void:
  if not status.cue.is_empty() and value==status.cue.to_upper():cue_alpha=color.a
  super._right(font,value,right,y,pixels,color,tracking)
var failures=[]
var checks=0
func expect(condition:bool,label:String)->void:
 checks+=1
 if not condition:failures.append(label)
func near(a:float,b:float,label:String)->void:expect(absf(a-b)<.00001,label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/motion-preference-reference.json"))
 for value in [-1,0,1]:Policy.refresh(value);expect(Policy.reduced==(value==1),"platform tri-state "+str(value))
 Policy.refresh(DisplayServer.accessibility_should_reduce_animation())
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 await process_frame;RenderingServer.force_draw(false)
 var platform_value=DisplayServer.accessibility_should_reduce_animation()
 expect(Policy.reduced==(platform_value==1),"actual GameUI platform wiring")
 game.game_ui.root.visible=false;game.weapon.slots.rifle.ammo=0
 var layer=CanvasLayer.new();layer.layer=21;root.add_child(layer)
 var results=[]
 for profile in reference.profiles:
  Policy.refresh(1 if profile.reduced else 0)
  var fade=preload("res://scripts/css_opacity_transition.gd").new(.1);fade.set_target(true)
  near(fade.timing.active_duration,float(profile.transitions.cross[0]),"cross duration")
  fade.advance(.001);expect(fade.value==1 if profile.reduced else fade.value<1,"cross effective sample")
  var hud=game.game_ui.hud_opacity_transition;hud.reset(0);hud.set_target(true)
  near(hud.timing.active_duration,float(profile.transitions.hud[0]),"HUD root exemption")
  var veil=game.game_ui.veil_opacity_transition;veil.reset(0);veil.set_target(true)
  near(veil.timing.active_duration,float(profile.transitions.veil[0]),"menu veil duration")
  var button=preload("res://scripts/title_button.gd").new();button.configure(false)
  button.color_transition.set_target([Color.RED,Color.GREEN,Color.BLUE],0)
  near(button.color_transition.timings[0].active_duration,float(profile.transitions.button[0]),"button color duration");button.free()
  var toggle=preload("res://scripts/panel_toggle.gd").new();toggle.configure(false);toggle.motion.set_target(true);toggle.colors.set_target([Color.RED],toggle.last_clock)
  near(toggle.motion.timing.active_duration,float(profile.transitions.toggle[0]),"toggle motion pseudo-element exemption")
  near(toggle.colors.timings[0].active_duration,float(profile.transitions.toggle[1]),"toggle color pseudo-element exemption");toggle.free()
  for sample in profile.samples:
   var style=preload("res://scripts/announcements_hud.gd").warning_style(float(sample.seconds))
   near(style.alpha,float(sample.warning_alpha),"warning opacity");near(style.spacing_em,float(sample.warning_spacing_em),"warning tracking")
  var location=preload("res://scripts/location_hud.gd")
  near(Policy.duration(1.1),float(profile.location_duration),"location CSS duration")
  expect(location.reveal_fraction(.001)==1.02 if profile.reduced else location.reveal_fraction(.001)<1,"location reveal")
  var status=Status.new();layer.add_child(status);status.setup(game.mission,game.weapon);status.update_frame(0);status.update_frame(.4)
  var objective=preload("res://scripts/objective_hud.gd").new();objective.position.x=16;layer.add_child(objective);objective.update_frame(.001,"Test",0,3)
  await process_frame;RenderingServer.force_draw(false)
  var cue_sample=profile.samples.filter(func(row):return row.seconds==.4)[0]
  near(status.cue_alpha,float(cue_sample.cue_alpha),"actual urgent cue draw")
  if profile.reduced:
   var pixel=root.get_texture().get_image().get_pixel(16,20);expect(absf(pixel.r-1)<.01 and absf(pixel.g-179.0/255)<.01 and absf(pixel.b-71.0/255)<.01,"reduced objective border final color")
  objective.update_frame(.1,"Typing remains active",0,3)
  expect(objective.characters==4,"JS objective typing preserved")
  var announcements=preload("res://scripts/announcements_hud.gd").new();announcements.warn("Wave",3.4);announcements.update_frame(.1,true)
  near(announcements.warning_remaining,3.3,"warning lifetime preserved");announcements.free()
  var feedback=SaltlineCombatFeedback.new();feedback.enemy_hit(false,false,"body",0);feedback.update(.05,Vector3.ZERO,0,false)
  var hit=[feedback.hit_opacity,feedback.hit_scale]
  feedback.enemy_killed("gull",0);feedback.update(3.61,Vector3.ZERO,0,true)
  var duration=feedback.feed[0].fade_duration
  near(duration,float(profile.transitions.feed[0]),"feed fade duration at start")
  Policy.refresh(0 if profile.reduced else 1);feedback.update(.001,Vector3.ZERO,0,false)
  near(feedback.feed[0].fade_duration,duration,"running feed fade retained after preference switch");near(feedback.feed[0].life,.59,"hidden feed lifetime preserved")
  results.append({"reduced":profile.reduced,"cue_alpha":status.cue_alpha,"hit":hit,"feed_duration":duration})
  status.dispose();status.queue_free();objective.queue_free();await process_frame
 near(results[0].hit[0],results[1].hit[0],"WAAPI hit opacity unaffected");near(results[0].hit[1],results[1].hit[1],"WAAPI hit scale unaffected")
 Policy.refresh(0)
 var timing=preload("res://scripts/css_transition_timing.gd").new();timing.duration=.5;timing.reset(0.0,0.0);timing.retarget(1.0,0.0,0.0)
 var opacity=timing.progress(.1);Policy.refresh(1)
 near(timing.active_duration*1000,float(reference.live_switch.during.duration_ms),"running transition duration retained")
 near(opacity,float(reference.live_switch.during.opacity),"running transition sample retained")
 timing.retarget(0.0,opacity,.1);near(timing.active_duration*1000,float(reference.live_switch.reversed.duration_ms),"new reversed transition uses reduced duration")
 Policy.refresh(platform_value)
 var report={"checks":checks,"failures":failures,"profiles":results,"platform_value":platform_value,"scope":"Actual GameUI platform wiring and production CSS helpers/components. Both preference responses injected only at policy boundary because Linux backend may return unsupported. Original Chrome CSS dual profiles/live-switch reference, pseudo-element/root exemptions, actual urgent-cue draw and objective GPU color, unchanged lifetimes/typing/WAAPI. No claim of a real OS reduced preference on unsupported backend."}
 FileAccess.open("res://evidence/motion-preference-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 layer.queue_free();game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
