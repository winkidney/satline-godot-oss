extends Control
var label_font:Font
var tag_font:Font
var items=[]
var pixels=13
var tracking=3.12
var layout_height=22.0
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 label_font=load("res://assets/fonts/barlow-condensed-600.ttf").duplicate();label_font.oversampling=1
 tag_font=load("res://assets/fonts/big-shoulders-display-900.ttf").duplicate();tag_font.oversampling=1
func width_of(value:String,font:Font,px:int,spacing:float)->float:return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x+value.length()*spacing
func layout(width:float,narrow:bool)->float:
 pixels=11 if narrow else 13;tracking=pixels*(.2 if narrow else .24);items=[]
 var definitions=[{"text":"B4","width":width_of("B4",tag_font,15,.9)+14,"height":22.0,"tag":true},{"text":"PORT AUTHORITY BREACH UNIT","width":width_of("PORT AUTHORITY BREACH UNIT",label_font,pixels,tracking),"height":pixels*1.2,"tag":false},{"text":"SALTLINE TERMINAL · 05:42","width":width_of("SALTLINE TERMINAL · 05:42",label_font,pixels,tracking),"height":pixels*1.2,"tag":false}]
 var x=0.0;var y=0.0;var row_height=0.0;var row=[]
 for definition in definitions:
  if x>0 and x+definition.width>width:
   for item in row:item.y=y+(row_height-item.height)*.5
   row=[];y+=row_height+6;x=0;row_height=0
  var item=definition.duplicate();item.x=x;item.y=y;items.append(item);row.append(item);x+=item.width+14;row_height=maxf(row_height,item.height)
 for item in row:item.y=y+(row_height-item.height)*.5
 layout_height=y+row_height;size=Vector2(width,layout_height);queue_redraw();return layout_height
func tracked(value:String,font:Font,px:int,spacing:float,origin:Vector2,line_height:float,color:Color)->void:
 var baseline=origin+Vector2(0,(line_height-font.get_height(px))*.5+font.get_ascent(px))
 for i in value.length():
  var at=baseline+Vector2(font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,px).x+i*spacing,0)
  draw_string(font,at,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)
func _draw()->void:
 for i in items.size():
  var item=items[i];var at=Vector2(item.x,item.y)
  if item.tag:
   draw_rect(Rect2(at,Vector2(item.width,item.height)),Color("ffb347"));tracked(item.text,tag_font,15,.9,at+Vector2(7,4),15,Color("0b0d0f"))
  else:tracked(item.text,label_font,pixels,tracking,at,pixels*1.2,Color(Color("e8e4da"),.64 if i==2 else 1))
