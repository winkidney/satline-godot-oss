extends SceneTree
var boot
var stages=[]
var failures=[]
var profile="normal"
var reference:Dictionary
func expect(condition:bool,label:String)->void:
 if not condition:failures.append(label)
func stage_shown(message:String,progress:float)->void:
 var row={"message":message,"progress":progress,"mark_pixels":boot.mark.pixels,"bar_width":boot.bar.size.x,"subtitle_y":boot.subtitle.position.y,"bar_y":boot.bar.position.y}
 stages.append(row)
 if progress==0 or progress==.5 or progress==1:root.get_texture().get_image().save_png("res://evidence/boot-%s-%02d.png"%[profile,stages.size()-1])
 if boot.game!=null and progress<.92:expect(boot.game.process_mode==Node.PROCESS_MODE_DISABLED and not boot.game.visible,"Main active during loading")
 if progress==.34:expect(boot.game.source_scene.materials.size()==195,"materials stage not completed")
 if progress==.5:expect(boot.game.source_scene.source_nodes.size()==729,"node stage not completed")
 if progress==0:
  expect(absf(boot.mark.pixels-float(reference.mark.pixels))<.0001,"boot logo size")
  expect(absf(boot.bar.size.x-float(reference.bar.width))<.0001,"boot progress width")
  expect(absf(boot.subtitle.position.y-float(reference.subtitle.y))<.1,"boot subtitle top")
  expect(absf(boot.bar.position.y-float(reference.bar.y))<.1,"boot bar top")
func _initialize()->void:call_deferred("run")
func run()->void:
 profile="reduced" if DisplayServer.accessibility_should_reduce_animation()==1 else "normal"
 var width=360 if profile=="reduced" else 1280;root.size=Vector2i(width,720)
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/boot-layout-reference.json"))
 reference=data.cases.filter(func(row):return int(row.width)==width and row.reduced==(profile=="reduced"))[0]
 boot=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();boot.stage_presented.connect(stage_shown);root.add_child(boot);current_scene=boot
 var game=await boot.ready_presented
 expect(current_scene==game and game.process_mode==Node.PROCESS_MODE_INHERIT and game.visible,"Main not resumed at Ready")
 expect(game.post_pipeline.combined_depth.is_ready_for(game.post_pipeline.world_port.size),"Ready before full world depth producer")
 expect(stages.size()==data.stages.size()+1,"boot stage count")
 for i in mini(data.stages.size(),stages.size()-1):
  expect(stages[i+1].message==data.stages[i].message and stages[i+1].progress==data.stages[i].progress,"original stage "+str(i))
 expect(absf(boot.opacity.timing.active_duration-float(reference.fade_duration))<.00001,"boot root fade duration")
 expect(boot.progress_timing.duration==reference.bar_duration and not boot.progress_timing.respects_motion_preference,"progress pseudo-element transition exemption")
 expect(boot.cover.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Ready still blocks input")
 await create_timer(.3).timeout
 if is_instance_valid(boot):
  root.get_texture().get_image().save_png("res://evidence/boot-"+profile+"-fade.png")
  expect(boot.cover.modulate.a==0 if profile=="reduced" else boot.cover.modulate.a>0 and boot.cover.modulate.a<1,"fade sample")
 await create_timer(.5).timeout
 expect(not is_instance_valid(boot),"boot retained beyond source700ms")
 expect(current_scene==game and game.game_flow.state=="title","startup did not reach title")
 root.get_texture().get_image().save_png("res://evidence/boot-"+profile+"-title.png")
 var report={"failures":failures,"profile":profile,"stages":stages,"entry_scene":ProjectSettings.get_setting("application/run/main_scene"),"scope":"Actual project startup scene, visible GPU boot snapshots, real asset milestones, Main disabled during initialization, ready after depth producer, source stage labels/weights, CSS layout/durations, pointer release, 700ms removal and actual title. No artificial policy override; reduced run requires private Portal1 fixture."}
 FileAccess.open("res://evidence/boot-"+profile+"-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
