extends RefCounted
# Rows 0..5 pool, 6..9 level points, 10 weapon key. Sun stays between
# the point and key BRDF calls, with its existing shadow data.
# Columns: position/range, linear radiance/decay, direction/type,
# original layer mask/visible/source intensity/reserved. Type: point=0,key=1.
const ROWS=11
var image:Image
var texture:ImageTexture
var lights:Array=[]
var identities:Array=[]
var masks:Array=[]
var uploads=0
func setup(scene:SaltlineSourceScene,pool:SaltlineLightPool,key:DirectionalLight3D)->void:
 for index in pool.slots.size():
  lights.append(pool.slots[index].light);identities.append("pool:"+str(index));masks.append(3)
 for record in scene.source.nodes:
  if record.type=="PointLight" and scene.records.get(record.parent,{}).get("name","")=="level-dynamic":
   lights.append(scene.source_nodes[record.id]);identities.append(record.id);masks.append(int(record.layers))
 lights.append(key);identities.append("viewmodel-key");masks.append(2)
 assert(lights.size()==ROWS,"Original local light layout must contain 10 points and one key")
 image=Image.create(4,ROWS,false,Image.FORMAT_RGBAF);texture=ImageTexture.create_from_image(image);update()
func update()->void:
 for row in lights.size():
  var light=lights[row];var intensity=float(light.get_meta("source_intensity",0.0));var rgb=light.light_color.srgb_to_linear();var position=light.global_position;var point=light is OmniLight3D;var direction=light.global_basis.z.normalized() if not point else Vector3.ZERO
  image.set_pixel(0,row,Color(position.x,position.y,position.z,light.omni_range if point else 0.0))
  image.set_pixel(1,row,Color(rgb.r*intensity,rgb.g*intensity,rgb.b*intensity,light.omni_attenuation if point else 0.0))
  image.set_pixel(2,row,Color(direction.x,direction.y,direction.z,0.0 if point else 1.0))
  image.set_pixel(3,row,Color(float(masks[row]),1.0 if light.is_visible_in_tree() else 0.0,intensity,0.0))
 texture.update(image);uploads+=1
func dispose()->void:
 texture=null;image=null;lights.clear();identities.clear();masks.clear()
