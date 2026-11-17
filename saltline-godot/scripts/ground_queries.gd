class_name SaltlineGroundQueries
extends RefCounted

var mask:PackedByteArray
var resolution:int
var mask_path:String
var interiors:Array
var metal_rects:Array=[]
const X0=-44.0
const Z0=-40.0
const SIZE=80.0
const QUAY_X=30.0

func _init(source:Dictionary)->void:
 var texture_id=""
 for material in source.materials:
  if material.get("uniforms",{}).has("uMask"):
   texture_id=str(material.uniforms.uMask.value["$texture"]);break
 assert(not texture_id.is_empty())
 for texture in source.textures:
  if texture.id==texture_id:
   resolution=int(texture.width);mask_path=str(texture.cpu_file) if texture.has("cpu_file") else "res://assets/export/"+str(texture.file);break
 mask=FileAccess.get_file_as_bytes(mask_path)
 assert(resolution>1 and mask.size()==resolution*resolution*4)
 interiors=source.modules.level.get("interiorBoxes",[])
 var metal=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/ground-metal-rects.json"))
 assert(int(source.seed)==int(metal.source_seed))
 for encoded in metal.rects_f64:
  var rect=PackedFloat64Array()
  for value in encoded:rect.append(decode_f64(value))
  metal_rects.append(rect)

static func decode_f64(encoded:String)->float:
 assert(encoded.length()==16)
 var bytes=PackedByteArray()
 for offset in range(0,16,2):bytes.append(encoded.substr(offset,2).hex_to_int())
 return bytes.decode_double(0)

func sample(x:float,z:float,channel:int)->float:
 var u=clampf((x-X0)/SIZE*resolution-.5,0,resolution-1.001)
 var v=clampf((z-Z0)/SIZE*resolution-.5,0,resolution-1.001)
 var ix=int(u);var iz=int(v);var tx=u-ix;var tz=v-iz
 var offset=(iz*resolution+ix)*4+channel;var stride=resolution*4
 return ((mask[offset]*(1-tx)+mask[offset+4]*tx)*(1-tz)+(mask[offset+stride]*(1-tx)+mask[offset+stride+4]*tx)*tz)/255.0

func is_interior(x:float,z:float)->bool:
 for box in interiors:
  if x>box.min[0] and x<box.max[0] and z>box.min[2] and z<box.max[2]:return true
 return false

func is_in_bounds(x:float,z:float)->bool:
 return x>X0 and x<X0+SIZE and z>Z0 and z<Z0+SIZE

func puddle_depth(x:float,z:float)->float:
 return -.2 if x>QUAY_X or not is_in_bounds(x,z) or is_interior(x,z) else .5-sample(x,z,0)

func is_puddle(x:float,z:float)->bool:return puddle_depth(x,z)>.015

func source_smoothstep(value:float,low:float,high:float)->float:
 if value<=low:return 0
 if value>=high:return 1
 var fraction=(value-low)/(high-low)
 return fraction*fraction*(3-2*fraction)

func wetness_at(x:float,z:float)->float:
 if x>QUAY_X:return 1
 if is_interior(x,z):return .12
 if not is_in_bounds(x,z):return .6
 var depth=.5-sample(x,z,0)
 if depth>.015:return 1
 var edge=source_smoothstep(depth,-.11,0)
 var rough=source_smoothstep(depth,-.65,-.02)
 var dry=1-source_smoothstep(sample(x,z,1)+rough*.55,.2,.42)
 return minf(.95,.25+(1-dry)*.4+edge*.3)

func ground_surface_at(x:float,z:float)->String:
 for rect in metal_rects:
  if x>=rect[0] and x<=rect[2] and z>=rect[1] and z<=rect[3]:return "metal"
 return "concrete"

func resolve_player_surface(position:Vector3,contact_surface:String)->String:
 if position.y<.05 and is_puddle(position.x,position.z):return "water"
 if not contact_surface.is_empty() and contact_surface!="concrete":return contact_surface
 return ground_surface_at(position.x,position.z)
