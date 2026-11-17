class_name SaltlineDecals
extends RefCounted

const CAPACITY=160
const TILES={"bullet_metal":[0,1],"bullet_concrete":[2,3],"bullet_wood":[4],"scorch":[5],"soot":[6],"bullet_glass":[7]}
const SIZES={"bullet_metal":.25,"bullet_concrete":.34,"bullet_wood":.24,"scorch":2.4,"soot":.3,"bullet_glass":.3}
var mesh:MeshInstance3D
var material:Material
var slots:Array=[]
var next=0
var rng=preload("res://scripts/fx_random.gd").new()
var emitted=0

func _init(scene:SaltlineSourceScene,random_stream=null)->void:
 if random_stream!=null:rng=random_stream
 for record in scene.source.nodes:
  if record.name=="fx_decals":mesh=scene.source_nodes[record.id];break
 assert(mesh!=null)
 material=mesh.mesh.surface_get_material(0);material.render_priority=-5

func impact(hit:Dictionary)->void:
 if hit.is_empty() or hit.surface in ["water","enemy"]:return
 if hit.surface in ["rubber","dirt"]:
  add(hit.point,hit.normal,"soot",.2,1,.8);return
 var kind="bullet_"+str(hit.surface)
 if not TILES.has(kind):kind="bullet_concrete"
 add(hit.point,hit.normal,kind)

func f32(value:float)->float:return PackedFloat32Array([value])[0]

func add(point:Vector3,normal:Vector3,kind:String,size:float=0,shade:float=1,alpha:float=1)->void:
 var choices:Array=TILES.get(kind,TILES.bullet_concrete);var tile:int=choices[rng.randi_range(0,choices.size()-1)]
 var half=(size if size!=0 else float(SIZES.get(kind,.25)))*(.85+rng.randf()*.3)*.5
 var nx=float(normal.x);var ny=float(normal.y);var nz=float(normal.z)
 var length=sqrt(nx*nx+ny*ny+nz*nz)
 if length==0:length=1
 nx/=length;ny/=length;nz/=length
 var tx=1.0 if abs(ny)>.9 else -nz;var ty=0.0;var tz=0.0 if abs(ny)>.9 else nx
 var dot=tx*nx+ty*ny+tz*nz
 tx-=nx*dot;ty-=ny*dot;tz-=nz*dot
 length=sqrt(tx*tx+ty*ty+tz*tz)
 if length==0:length=1
 tx/=length;ty/=length;tz/=length
 var bx=ny*tz-nz*ty;var by=nz*tx-nx*tz;var bz=nx*ty-ny*tx
 var angle=(rng.randf()-.5)*.3 if kind=="bullet_wood" else rng.randf()*6.283
 var cosine=cos(angle);var sine=sin(angle)
 var ax=(tx*cosine+bx*sine)*half;var ay=(ty*cosine+by*sine)*half;var az=(tz*cosine+bz*sine)*half
 var dx=(bx*cosine-tx*sine)*half;var dy=(by*cosine-ty*sine)*half;var dz=(bz*cosine-tz*sine)*half
 var offset=.004+(next%7)*.0003
 var cx=point.x+nx*offset;var cy=point.y+ny*offset;var cz=point.z+nz*offset
 var margin=2.0/256
 var column=tile%4;var row=tile/4
 var uv=Vector4((column+margin)/4,1-(row+1-margin)/2,(column+1-margin)/4,1-(row+margin)/2)
 var record={"positions":[Vector3(cx-ax-dx,cy-ay-dy,cz-az-dz),Vector3(cx+ax-dx,cy+ay-dy,cz+az-dz),Vector3(cx+ax+dx,cy+ay+dy,cz+az+dz),Vector3(cx-ax+dx,cy-ay+dy,cz-az+dz)],"normal":Vector3(nx,ny,nz),"uv":uv,"shade":f32(shade),"alpha":f32(alpha),"base_alpha":f32(alpha),"kind":kind}
 if slots.size()<CAPACITY:slots.append(record)
 else:slots[next]=record
 next=(next+1)%CAPACITY;emitted+=1
 if slots.size()>=CAPACITY:
  for i in 14:
   var old:Dictionary=slots[(next+i)%CAPACITY];old.alpha=f32(old.base_alpha*(i+1)/15)
 _rebuild()

func _rebuild()->void:
 var positions=PackedVector3Array();var normals=PackedVector3Array();var uvs=PackedVector2Array();var colors=PackedFloat32Array();var raw_normals=PackedFloat32Array();var indices=PackedInt32Array()
 for slot in slots:
  var base=positions.size();positions.append_array(PackedVector3Array(slot.positions))
  for i in 4:
   normals.append(slot.normal);raw_normals.append_array(PackedFloat32Array([slot.normal.x,slot.normal.y,slot.normal.z,0]));colors.append_array(PackedFloat32Array([slot.shade,slot.shade,slot.shade,slot.alpha]))
  var uv:Vector4=slot.uv
  uvs.append_array(PackedVector2Array([Vector2(uv.x,uv.y),Vector2(uv.z,uv.y),Vector2(uv.z,uv.w),Vector2(uv.x,uv.w)]))
  indices.append_array(PackedInt32Array([base,base+2,base+1,base,base+3,base+2]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_CUSTOM2]=raw_normals;arrays[Mesh.ARRAY_CUSTOM3]=colors;arrays[Mesh.ARRAY_INDEX]=indices
 var replacement=ArrayMesh.new();replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT));replacement.surface_set_material(0,material)
 mesh.mesh=replacement;mesh.visible=true

func clear()->void:
 slots.clear();next=0;mesh.visible=false
