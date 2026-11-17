extends Control
var source=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/control-content.json"))
var fonts={}
var operations=[]
var last_width=-1.0
var row_count=0
func _init()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for key in ["label","heading","mono","note"]:
  var file={"label":"barlow-condensed-500.ttf","heading":"barlow-condensed-600.ttf","mono":"ibm-plex-mono-500.ttf","note":"ibm-plex-mono-400.ttf"}[key]
  var font=load("res://assets/fonts/"+file).duplicate();font.oversampling=1.0;fonts[key]=font
func measure(text:String,font:String,pixels:int,tracking:float)->float:
 return fonts[font].get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x+text.length()*tracking
func packets(spans:Array,note:bool)->Array:
 var result=[];var regex=RegEx.new();regex.compile("\\S+|\\s+")
 for span in spans:
  if span.kind=="key":
   var tracking=.22 if note else .52
   result.append({"kind":"key","text":span.text.to_upper(),"font":"mono","pixels":10,"tracking":tracking,"width":maxf(18,measure(span.text.to_upper(),"mono",10,tracking)+10)+2,"space":false})
  else:
   for matched in regex.search_all(str(span.text)):
    var text=matched.get_string();var space=text.strip_edges().is_empty()
    if space:text=" "
    var font="note" if note else "label";var pixels=11 if note else 13;var tracking=.22 if note else .52
    result.append({"kind":"text","text":text,"font":font,"pixels":pixels,"tracking":tracking,"width":measure(text,font,pixels,tracking),"space":space})
 return result
func line_width(line:Array)->float:
 var width=0.0
 for token in line:width+=token.width
 return width
func trim_line(line:Array)->void:
 while not line.is_empty() and line[-1].space:line.pop_back()
func wrapped(tokens:Array,width:float)->Array:
 var lines=[];var line=[]
 for token in tokens:
  if line.is_empty() and token.space:continue
  if not line.is_empty() and line_width(line)+token.width>width and not token.space:
   trim_line(line);lines.append(line);line=[]
  if line.is_empty() and token.space:continue
  line.append(token)
 trim_line(line)
 if not line.is_empty():lines.append(line)
 return lines
func text_op(text:String,font:String,pixels:int,tracking:float,point:Vector2,height:float,color:Color)->void:
 operations.append({"kind":"text","text":text,"font":font,"pixels":pixels,"tracking":tracking,"point":point,"height":height,"color":color})
func inline_ops(line:Array,x:float,y:float,height:float,note:bool)->void:
 for token in line:
  if token.kind=="key":
   var box=token.width-2
   operations.append({"kind":"box","rect":Rect2(x+1.5,y+.5,box-1,16)})
   var width=measure(token.text,token.font,token.pixels,token.tracking)
   text_op(token.text,"mono",10,token.tracking,Vector2(x+1+(box-width)*.5,y+4),10,Color("e8e4da"))
  else:text_op(token.text,token.font,token.pixels,token.tracking,Vector2(x,y),height,Color("8d9aa3") if note else Color("e8e4da"))
  x+=token.width
func reflow(width:float)->void:
 operations=[];row_count=0;last_width=width;var y=0.0
 for block in source.blocks:
  if block.kind=="heading":
   y+=20;text_op(str(block.text).to_upper(),"heading",11,2.86,Vector2(0,y),11,Color("8d9aa3"));y+=19.5
   operations.append({"kind":"line","y":y});y+=8.5
  elif block.kind=="table":
   for row in block.rows:
    var label=str(row.label).to_upper();var label_width=measure(label,"label",12,1.92)
    var lines=wrapped(packets(row.spans,false),maxf(1,width-label_width-12));var line_height=float(row.get("binding_line_height",17.0))
    text_op(label,"label",12,1.92,Vector2(0,y+float(row.get("label_offset",3))),15.6,Color("8d9aa3"))
    for i in lines.size():inline_ops(lines[i],width-line_width(lines[i]),y+3+i*line_height,line_height,false)
    y+=maxi(1,lines.size())*line_height+6;row_count+=1
  elif block.kind=="note":
   y+=14;var lines=wrapped(packets(block.spans,true),width)
   for line in lines:inline_ops(line,0,y,17.6,true);y+=17.6
 custom_minimum_size.y=ceil(y);queue_redraw()
func _process(_dt:float)->void:
 if size.x>0 and absf(last_width-size.x)>.01:reflow(size.x)
func _draw()->void:
 for op in operations:
  if op.kind=="box":draw_rect(op.rect,Color(Color("e8e4da"),.45),false,1)
  elif op.kind=="line":draw_line(Vector2(0,op.y),Vector2(size.x,op.y),Color(Color("e8e4da"),.2),1)
  else:
   var font:Font=fonts[op.font];var baseline=op.point+Vector2(0,(op.height-font.get_height(op.pixels))*.5+font.get_ascent(op.pixels))
   for i in op.text.length():
    draw_string(font,baseline+Vector2(measure(op.text.left(i),op.font,op.pixels,op.tracking),0),op.text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,op.pixels,op.color)
