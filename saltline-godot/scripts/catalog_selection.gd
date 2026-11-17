extends RefCounted
static func _camera(data:Dictionary,position:Array,target:Array)->void:
 var transform=Transform3D(Basis.IDENTITY,Vector3(position[0],position[1],position[2])).looking_at(Vector3(target[0],target[1],target[2]),Vector3.UP)
 var q=transform.basis.get_rotation_quaternion();data.camera.position=position;data.camera.quaternion=[q.x,q.y,q.z,q.w];data.selection_camera={"position":position,"target":target}
static func _prune(data:Dictionary)->void:
 var mats={};var geometries={};var textures={}
 for node in data.nodes:
  geometries[node.geometry]=true
  for id in node.get("materials",[node.material]):mats[id]=true
 data.materials=data.materials.filter(func(record):return mats.has(record.id));data.geometries=data.geometries.filter(func(record):return geometries.has(record.id))
 for material in data.materials:_textures(material,textures)
 data.textures=data.textures.filter(func(record):return textures.has(record.id))
static func _textures(value:Variant,output:Dictionary)->void:
 if value is Dictionary:
  if value.has("$texture"):output[value["$texture"]]=true
  for child in value.values():_textures(child,output)
 elif value is Array:
  for child in value:_textures(child,output)
static func _layout(names:Array,sizes:Dictionary)->Dictionary:
 var x=0.0;var z=0.0;var depth=0.0;var extent=0.0;var placements=[]
 for name in names:
  var size=sizes[name]
  if x+size[0]>26:x=0;z+=depth+1.5;depth=0
  placements.append([x+size[0]/2.0,0.0,z]);x+=size[0]+1;depth=maxf(depth,size[2]);extent=maxf(extent,x)
 var center=minf(extent,26)/2
 return {"placements":placements,"position":[center-4,2.2,z+depth+6],"target":[center,1,z/2]}
static func props(source:Dictionary,names:Array,inventory:Dictionary)->Dictionary:
 var data=source.duplicate(true);var sizes={}
 for prop in inventory.state.props:sizes[prop.name]=prop.size
 for name in names:
  if not sizes.has(name):return {"error":"Unknown prop: "+str(name)}
 var old=_layout(source.requested,sizes);var next=_layout(names,sizes);var nodes=[]
 for index in names.size():
  var previous=old.placements[source.requested.find(names[index])];var position=next.placements[index]
  for record in source.nodes:
   if record.get("prop")!=names[index]:continue
   var node=record.duplicate(true);node.id+="-selection-"+str(index)
   for axis in 3:node.matrix[12+axis]+=position[axis]-previous[axis]
   nodes.append(node)
 for record in source.nodes:
  if record.get("prop")==null:nodes.append(record.duplicate(true))
 data.nodes=nodes;data.requested=names;_camera(data,next.position,next.target);_prune(data);return data
static func materials(source:Dictionary,only:Array)->Dictionary:
 var data=source.duplicate(true);var names=only.filter(func(name):return name!="decals")
 for name in names:
  if name not in source.requested:return {"error":"Unknown material: "+str(name)}
 var columns=maxi(1,names.size());var nodes=[];var width=columns*1.9
 for index in names.size():
  var original=source.requested.find(names[index]);var x=(index-(columns-1)/2.0)*1.9
  for slot in 3:
   var node=source.nodes[original*3+slot].duplicate(true);node.id+="-selection-"+str(index)
   node.matrix[12]+=x-source.nodes[original*3].matrix[12];node.matrix[14]+=floor(float(original)/10.0)*3.6
   nodes.append(node)
 if "decals" in only:
  var x=0.0 if names.is_empty() else width/2+5.5
  var original_wall=source.nodes[source.requested.size()*3].matrix[12]
  for index in range(source.requested.size()*3,source.nodes.size()-1):
   var node=source.nodes[index].duplicate(true);node.matrix[12]+=x-original_wall;nodes.append(node)
 nodes.append(source.nodes[-1].duplicate(true));data.nodes=nodes;data.requested=names
 if names.is_empty() and "decals" in only:_camera(data,[4.2,1.7,7.2],[4.2,1.6,-1])
 elif names.is_empty():_camera(data,[0,9.5,12],[0,0,-7])
 else:_camera(data,[.25*width,1.5,2.6+width*.42],[0,.62,.5])
 _prune(data);return data
