extends Control
var font:Font
var font_path="res://assets/fonts/barlow-condensed-500.ttf"
var tracking_em=.03
var line_height_em=1.3
var text_color=Color(Color("e8e4da"),.9)
var text="The port’s security net has gone feral. Cut its three uplinks. Reach the boat."
var pixels=17.0
var tracking=.51
var lines=[]
var layout_height=22.1
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;font=load(font_path).duplicate();font.oversampling=1
func width_of(value:String)->float:
 var raster=int(ceil(pixels));return font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,raster).x*pixels/raster+value.length()*tracking
func layout(width:float,font_pixels:float)->float:
 pixels=font_pixels;tracking=pixels*tracking_em;lines=[];var current=""
 for word in text.split(" "):
  var next=word if current.is_empty() else current+" "+word
  if not current.is_empty() and width_of(next)>width:lines.append(current);current=word
  else:current=next
 lines.append(current);layout_height=lines.size()*pixels*line_height_em;size=Vector2(width,layout_height);queue_redraw();return layout_height
func _draw()->void:
 var raster=int(ceil(pixels));var ratio=pixels/raster
 var baseline=(pixels*line_height_em-font.get_height(raster)*ratio)*.5+font.get_ascent(raster)*ratio
 for row in lines.size():
  var value=lines[row]
  for i in value.length():
   var x=font.get_string_size(value.left(i),HORIZONTAL_ALIGNMENT_LEFT,-1,raster).x*ratio+i*tracking
   draw_set_transform(Vector2(x,baseline+row*pixels*line_height_em),0,Vector2.ONE*ratio)
   draw_string(font,Vector2.ZERO,value[i],HORIZONTAL_ALIGNMENT_LEFT,-1,raster,text_color)
 draw_set_transform(Vector2.ZERO)
