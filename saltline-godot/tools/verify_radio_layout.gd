extends SceneTree

class ObservedRadio extends "res://scripts/radio_hud.gd":
 var draws=[]
 func tracked(value:String,font:Font,pixels:int,spacing:float,top:Vector2,line_height:float,color:Color)->void:
  draws.append({"text":value,"pixels":pixels,"spacing":spacing,"line_height":line_height})
  super.tracked(value,font,pixels,spacing,top,line_height,color)

func _initialize()->void:call_deferred("run")
func run()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/radio-layout-reference.json"))
 var radio=ObservedRadio.new();root.add_child(radio)
 var failures=[];var cases=[]
 for sample in reference.cases:
  root.size=Vector2i(int(sample.width),720)
  for touch in [false,true]:
   radio.touch_layout=touch;radio.draws.clear();radio.update_frame(1,sample.text,true)
   await process_frame;RenderingServer.force_draw(false)
   var body=radio.draws.filter(func(row):return row.text!="CONTROL")
   var lines=[]
   for row in body:
    lines.append(row.text)
    for key in ["pixels","spacing","line_height"]:
     if absf(float(row[key])-float(sample[key]))>.00001:failures.append("typography %s %s"%[sample.width,key])
   if lines!=sample.lines:failures.append("line wrapping %s touch=%s: %s"%[sample.width,touch,str(lines)])
   if body.is_empty():failures.append("no actual draw calls")
   var file="res://evidence/radio-layout-%d-%s%s.png"%[sample.width,"touch" if touch else "desktop","-final-fragment" if sample.text!=reference.text else ""]
   root.get_texture().get_image().save_png(file)
   cases.append({"width":sample.width,"touch":touch,"draws":body,"source_line_widths":sample.lines.map(func(value):return radio.text_width(value,radio.body_font,int(sample.pixels),float(sample.spacing))),"capture":file})
 var report={"failures":failures,"cases":cases,"scope":"Actual RadioHud draw calls and GPU screenshots at four window widths in desktop/touch layouts, compared with original CSS computed typography and text line wrapping. No whole-image pixel equivalence claim."}
 FileAccess.open("res://evidence/radio-layout-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report))
 radio.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
