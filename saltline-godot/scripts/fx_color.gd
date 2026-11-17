extends RefCounted
# Original ph/e5: only number/string parsing updates the shared cached color.
var cached=PackedFloat64Array([1,1,1])
var names:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fx-css-colors.json"))
func _match(pattern:String,text:String)->RegExMatch:
 var regex=RegEx.new();regex.compile(pattern);return regex.search(text)
func _linear(value:float)->float:
 return value*.0773993808 if value<.04045 else pow(value*.9478672986+.0521327014,2.4)
func _rgb(r:float,g:float,b:float)->void:cached=PackedFloat64Array([_linear(r),_linear(g),_linear(b)])
func _hex(value:float)->void:
 var bits=int(floor(value)) if is_finite(value) else 0
 _rgb(float((bits>>16)&255)/255,float((bits>>8)&255)/255,float(bits&255)/255)
func _hue(p:float,q:float,t:float)->float:
 if t<0:t+=1
 if t>1:t-=1
 if t<1.0/6:return p+(q-p)*6*t
 if t<.5:return q
 if t<2.0/3:return p+(q-p)*6*(2.0/3-t)
 return p
func parse(value:Variant,fallback:PackedFloat64Array=PackedFloat64Array([.32,.32,.33]))->PackedFloat64Array:
 if value==null:return fallback.duplicate()
 if value is Array or value is PackedFloat64Array:return PackedFloat64Array(value)
 if value is Color:return PackedFloat64Array([value.r,value.g,value.b])
 if value is Vector3:return PackedFloat64Array([value.x,value.y,value.z])
 if value is Dictionary and value.get("isColor",false):return PackedFloat64Array([value.r,value.g,value.b])
 if value is int or value is float:_hex(float(value))
 elif value is String:
  var model=_match(r"^(\w+)\(([^\)]*)\)",value)
  var hex=_match(r"^#([A-Fa-f\d]+)$",value)
  if model:
   var kind=model.get_string(1);var body=model.get_string(2)
   if kind in ["rgb","rgba"]:
    var result=_match(r"^\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d*\.?\d+)\s*)?$",body)
    var limit=255.0
    if result==null:
     result=_match(r"^\s*(\d+)%\s*,\s*(\d+)%\s*,\s*(\d+)%\s*(?:,\s*(\d*\.?\d+)\s*)?$",body);limit=100
    if result:_rgb(minf(limit,float(result.get_string(1)))/limit,minf(limit,float(result.get_string(2)))/limit,minf(limit,float(result.get_string(3)))/limit)
   elif kind in ["hsl","hsla"]:
    var result=_match(r"^\s*(\d*\.?\d+)\s*,\s*(\d*\.?\d+)%\s*,\s*(\d*\.?\d+)%\s*(?:,\s*(\d*\.?\d+)\s*)?$",body)
    if result:
     var h=fposmod(float(result.get_string(1))/360,1);var s=clampf(float(result.get_string(2))/100,0,1);var l=clampf(float(result.get_string(3))/100,0,1)
     var q=l*(1+s) if l<=.5 else l+s-l*s;var p=2*l-q
     if s==0:_rgb(l,l,l)
     else:_rgb(_hue(p,q,h+1.0/3),_hue(p,q,h),_hue(p,q,h-1.0/3))
  elif hex:
   var digits=hex.get_string(1)
   if digits.length()==6:_hex(float(digits.hex_to_int()))
   elif digits.length()==3:_rgb(float(digits.substr(0,1).hex_to_int())/15,float(digits.substr(1,1).hex_to_int())/15,float(digits.substr(2,1).hex_to_int())/15)
  elif names.has(value.to_lower()):_hex(float(names[value.to_lower()]))
 return cached.duplicate()
