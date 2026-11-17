extends SceneTree

class Objective extends "res://scripts/objective_hud.gd":
 var draws=[]
 func tracked(value:String,origin:Vector2,font:Font,pixels:int,spacing:float,color:Color)->void:
  draws.append({"text":value,"y":origin.y,"pixels":pixels,"spacing":spacing})
  super.tracked(value,origin,font,pixels,spacing,color)
class Navigation extends "res://scripts/navigation_hud.gd":
 var headings=0
 func css_text(font:Font,value:String,point:Vector2,pixels:int,line_height:float,spacing:float,color:Color,center:bool=true)->void:
  if font==heading_font:headings+=1
  super.css_text(font,value,point,pixels,line_height,spacing,color,center)
class Status extends "res://scripts/status_hud.gd":
 var draws=[]
 func _right(font:Font,value:String,right:float,y:float,pixels:int,color:Color,tracking:float=0)->void:
  draws.append({"text":value,"y":y,"pixels":pixels,"ammo":font==display})
  super._right(font,value,right,y,pixels,color,tracking)
 func _text(font:Font,value:String,point:Vector2,pixels:int,color:Color,tracking:float=0)->void:
  if value=="VITALS":draws.append({"text":value,"y":point.y,"pixels":pixels,"ammo":false})
  super._text(font,value,point,pixels,color,tracking)

var failures=[]
func expect(condition:bool,label:String)->void:
 if not condition:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/responsive-hud-reference.json"))
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 game.set_process(false);game.set_physics_process(false);game.game_flow.storage_path="";game.game_ui.save_path=""
 game.game_flow.start("mission",false,false,true);game.game_ui.root.visible=false
 game.player.health=70;game.weapon.slots.rifle.ammo=1
 var layer=CanvasLayer.new();layer.layer=game.game_ui.layer+1;root.add_child(layer)
 var objective=Objective.new();objective.position.x=16;layer.add_child(objective)
 var nav=Navigation.new();layer.add_child(nav);nav.setup(game.mission,game.camera,game.weapon)
 var status=Status.new();layer.add_child(status);status.setup(game.mission,game.weapon)
 var rows=[]
 for sample in reference.cases:
  root.size=Vector2i(int(sample.width),720)
  for i in 3:await process_frame
  objective.draws.clear();nav.headings=0;status.draws.clear()
  objective.update_frame(10,reference.text,0,3)
  nav.touch_layout=sample.touch;nav.update_frame(1.0/60)
  status.touch_layout=sample.touch;status.update_frame(1)
  await process_frame;RenderingServer.force_draw(false)
  var label="%s touch=%s"%[sample.width,sample.touch]
  expect(objective.position.y==sample.objective.top,label+" objective top")
  var lines=[];var relay_y=0.0
  for row in objective.draws:
   if row.text in ["OBJECTIVE","0/3"]:continue
   if row.text=="RELAYS":relay_y=row.y;continue
   lines.append(row.text)
   expect(row.pixels==sample.objective_text.pixels and absf(row.spacing-float(sample.objective_text.spacing))<.00001,label+" objective typography")
  expect(lines==sample.objective_lines,label+" objective lines "+str(lines))
  expect(absf(objective.position.y+relay_y-float(sample.relays.top))<.05,label+" relay row top")
  expect(nav.headings==(0 if sample.heading.display=="none" else 1),label+" heading visibility")
  var ammo=status.draws.filter(func(row):return row.ammo)[0]
  expect(ammo.pixels==sample.ammo_text.pixels,label+" ammo font")
  var cue=status.draws.filter(func(row):return row.text=="LOW AMMO")[0]
  var health=status.draws.filter(func(row):return row.text=="VITALS")[0]
  rows.append({"width":sample.width,"touch":sample.touch,"ammo":ammo,"cue":cue,"health":health,"objective_lines":lines,"objective_y":objective.position.y,"headings":nav.headings})
  root.get_texture().get_image().save_png("res://evidence/responsive-hud-%d-%s.png"%[sample.width,"touch" if sample.touch else "desktop"])
 for touch in [false,true]:
  var narrow=rows.filter(func(row):return row.width==760 and row.touch==touch)[0]
  var wide=rows.filter(func(row):return row.width==761 and row.touch==touch)[0]
  var ns=reference.cases.filter(func(row):return row.width==760 and row.touch==touch)[0]
  var ws=reference.cases.filter(func(row):return row.width==761 and row.touch==touch)[0]
  expect(absf((narrow.cue.y-wide.cue.y)-(float(ns.cue.top)-float(ws.cue.top)))<.05,"cue breakpoint movement touch="+str(touch))
  if touch:
   expect(absf((narrow.ammo.y-wide.ammo.y)-(float(ns.ammo.top)-float(ws.ammo.top)))<.05,"touch ammo breakpoint movement")
   expect(absf((narrow.health.y-wide.health.y)-(float(ns.health.top)-float(ws.health.top)))<.05,"touch health breakpoint movement")
 status.dispose();layer.queue_free();await process_frame
 root.size=Vector2i(360,720);game.game_ui.root.visible=true;game.source_touch_input.enabled=true
 game.player.health=100;game.player.damage(30)
 var resumes=0
 for i in 60:
  if game.game_flow.state=="paused":game.game_flow.resume();resumes+=1
  game._game_tick(1.0/60,{"move":Vector2.ZERO,"fire":false});game._process(1.0/60);await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png("res://evidence/responsive-hud-main-360-touch.png")
 var report={"failures":failures,"cases":rows,"main_capture":"responsive-hud-main-360-touch.png","controlled_focus_resumes":resumes,"scope":"Production HUD draw methods, actual Main mission/weapon and production stretch configuration. Four widths desktop/touch vs original CSS objective top/font/wrap/relay row, heading visibility, ammo font and breakpoint movements. Final capture uses actual GameUI after removing observers. Not whole-image pixels or HiDPI."}
 FileAccess.open("res://evidence/responsive-hud-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
