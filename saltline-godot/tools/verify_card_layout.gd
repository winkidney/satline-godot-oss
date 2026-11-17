extends SceneTree
var failures=[]
func expect(condition:bool,label:String)->void:
 if not condition:failures.append(label)
func settle()->void:
 for i in 6:await process_frame
 RenderingServer.force_draw(false)
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/card-layout-reference.json"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 game.game_flow.storage_path="";game.game_ui.save_path=""
 for c in game.game_flow.capture_mouse.get_connections():game.game_flow.capture_mouse.disconnect(c.callable)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 game.mission.debrief={"rating":"Clean","time":30.0,"accuracy":.5,"kills":3,"retries":0}
 game.game_flow.holdout_result={"waves":2,"kills":16,"score":3820,"best":3820}
 var ui=game.game_ui;var rows=[];var scroll_cases=0
 for sample in reference.cases:
  root.size=Vector2i(int(sample.width),int(sample.height));await settle()
  game.mission.run.mode=sample.mode;game.game_flow.menu=sample.screen;game.game_flow.state=sample.screen
  ui._show(sample.screen);await settle();ui.update_frame(0);await settle()
  var label="%dx%d %s %s"%[sample.width,sample.height,sample.screen,sample.mode]
  var rect=ui.card.get_global_rect();var expected=sample.card
  for pair in [[rect.position.x,expected.x],[rect.position.y,expected.y],[rect.size.x,expected.width],[rect.size.y,expected.height]]:
   expect(absf(float(pair[0])-float(pair[1]))<.15,label+" card rectangle "+str(pair))
  expect(absf(ui.card_content.heading_pixels-float(sample.heading_pixels))<.0001,label+" heading font")
  if sample.rating_pixels!=null:expect(ui.card_content.rating_pixels==sample.rating_pixels,label+" rating font")
  expect(rect.position.x>=0 and rect.end.x<=sample.width+.1 and rect.position.y>=11.9 and rect.end.y<=sample.height-11.9,label+" viewport bounds")
  var reached=[]
  for i in ui.card_actions.get_child_count():
   var button=ui.card_actions.get_child(i);button.grab_focus();await settle()
   var b=button.get_global_rect();var viewport=ui.card_scroll.get_global_rect()
   expect(absf(button.size.y-float(sample.button_heights[i]))<.05,label+" button height")
   expect(absf(button.size.x-float(sample.button_widths[i]))<.05,label+" button width")
   expect(b.position.y>=viewport.position.y-.1 and b.end.y<=viewport.end.y+.1,label+" focused action not reachable "+button.text)
   expect(b.position.x>=rect.position.x and b.end.x<=rect.end.x,label+" action clipped horizontally")
   reached.append({"text":button.text,"rect":[b.position.x,b.position.y,b.size.x,b.size.y],"scroll":ui.card_scroll.scroll_vertical})
  if float(sample.scroll_height)>float(sample.client_height)+1:
   scroll_cases+=1;expect(ui.card_scroll.get_v_scroll_bar().max_value>ui.card_scroll.get_v_scroll_bar().page,label+" missing required scrolling")
  rows.append({"window":[sample.width,sample.height],"screen":sample.screen,"mode":sample.mode,"card":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"heading_pixels":ui.card_content.heading_pixels,"actions":reached})
  root.get_texture().get_image().save_png("res://evidence/card-layout-%dx%d-%s-%s.png"%[sample.width,sample.height,sample.screen,sample.mode])
 expect(scroll_cases>0,"fixture never exercised real overflow")
 root.size=Vector2i(1280,720);game.game_flow.menu="title";game.game_flow.state="title";ui._show("title");await settle();ui.update_frame(0);await settle()
 expect(ui.buttons.settings==ui.responsive_title.action_buttons[1] and ui.buttons.controls==ui.responsive_title.action_buttons[2],"title action identity restored")
 ui.buttons.settings.pressed.emit();await settle();expect(ui.panel_open,"title settings action after card reuse");ui.close_panel();await settle()
 game.game_flow.state="paused";game.game_flow.menu="paused";ui._show("paused");await settle()
 for dimensions in [Vector2i(360,720),Vector2i(640,240),Vector2i(1280,720)]:
  root.size=dimensions;await settle();ui.update_frame(0);await settle()
  expect(absf(ui.card.size.x-minf(430,dimensions.x-32))<.05,"live card width "+str(dimensions))
  if dimensions.y==240:
   ui.buttons.restart.grab_focus();await settle();expect(ui.card_scroll.scroll_vertical>0,"live short card focus did not scroll")
  if dimensions.x==1280:expect(ui.card_scroll.scroll_vertical==0 and not ui.card_scrollbar.visible,"live tall card retained overflow")
 ui.buttons.resume.pressed.emit();await settle();expect(game.game_flow.state=="playing","actual resume action after resize")
 var report={"failures":failures,"cases":rows,"scroll_cases":scroll_cases,"scope":"Actual Main GameUI pause/death/complete cards vs original DOM/CSS across four window sizes, mission/holdout rows, typography, button sizes, viewport containment and focus-follow scrolling. Return-to-title action identity and settings signal after card reuse. No fixture scale override. Not full raster text parity or HiDPI."}
 FileAccess.open("res://evidence/card-layout-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
