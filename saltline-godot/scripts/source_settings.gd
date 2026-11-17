extends RefCounted
const DEFAULTS={"quality":"auto","sens":1.0,"invertY":false,"fov":74.0,"difficulty":"hard","mode":"mission","view":1,"volume":0.8}
static func number(value:Variant)->bool:return (value is int or value is float) and is_finite(float(value))
static func truthy(value:Variant)->bool:
 if value==null:return false
 if value is bool:return value
 if value is int or value is float:return value!=0 and not is_nan(float(value))
 if value is String:return not value.is_empty()
 return true
static func decode(raw:String)->Dictionary:
 var result=DEFAULTS.duplicate();var parser=JSON.new()
 if parser.parse(raw)!=OK:return result
 var data=parser.data
 if not data is Dictionary:return result
 if data.get("quality") in ["auto","low","medium","high","ultra"]:result.quality=data.quality
 if number(data.get("sens")):result.sens=clampf(data.sens,.2,3)
 result.invertY=truthy(data.get("invertY"))
 if number(data.get("fov")):result.fov=clampf(data.fov,60,95)
 if number(data.get("volume")):result.volume=clampf(data.volume,0,1)
 if data.get("difficulty") in ["standard","hard","brutal"]:result.difficulty=data.difficulty
 if data.get("mode") in ["mission","holdout"]:result.mode=data.mode
 if number(data.get("view")) and (float(data.view)==1.0 or float(data.view)==2.0 or float(data.view)==3.0):result.view=int(data.view)
 return result
