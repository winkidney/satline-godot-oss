extends SceneTree
func _initialize()->void:call_deferred("run")
func as_bytes(value)->PackedByteArray:return value.to_byte_array() if value is PackedFloat32Array else value
func run()->void:
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false);RenderingServer.force_draw(false);var source=game.source_scene;var failures=[];var reports=[];var clocks=[];var expected_time=source.backdrop_time
 for entry in [["playing",.1,.05],["paused",.04,0.0],["paused",.2,0.0]]:
  game.game_flow.state=entry[0];game._process(entry[1]);expected_time+=entry[2];var error=absf(source.backdrop_time-expected_time)
  for material in source.backdrop_materials:error=maxf(error,absf(float(material.get_shader_parameter("source_backdrop_time"))-expected_time))
  clocks.append({"state":entry[0],"render_dt":entry[1],"expected_time":expected_time,"maximum_error":error})
  if error>.000001:failures.append("backdrop simulation clock "+entry[0])
 if source.backdrop_materials.size()!=2:failures.append("expected two backdrop materials")
 var viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.use_hdr_2d=true;viewport.world_3d=World3D.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);var environment=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;viewport.world_3d.environment=environment
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.01;camera.far=400;viewport.add_child(camera);camera.current=true;var mesh=MeshInstance3D.new();viewport.add_child(mesh)
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/backdrop-reference.json"))
 for record in source.source.nodes:
  if not record.has("geometry"):continue
  var geometry=source.geometry_records[record.geometry];var orbit=geometry.attributes.has("aOrbit")
  if not orbit and not geometry.attributes.has("blink"):continue
  var original=source.source_nodes[record.id];mesh.mesh=original.mesh;mesh.custom_aabb=original.custom_aabb;var material=source.materials[record.materials[0]];var mode=int(material.get_shader_parameter("source_backdrop_mode"));var exact=true;var arrays=mesh.mesh.surface_get_arrays(0)
  for pair in ([["aOrbit",0],["aPar",1]] if orbit else [["blink",0]]):
   var attr=geometry.attributes[pair[0]];var values=source._floats(attr);var packed=PackedFloat32Array();packed.resize(int(attr.count)*4)
   for vertex in int(attr.count):
    for channel in int(attr.itemSize):packed[vertex*4+channel]=values[vertex*int(attr.itemSize)+channel]
   exact=exact and as_bytes(arrays[Mesh.ARRAY_CUSTOM0+pair[1]])==packed.to_byte_array()
  if not exact or mode!=(2 if orbit else 1):failures.append("source attribute or mode "+record.id)
  var times=[.05,.4];var dynamic=true
  if orbit:
   var p=reference.cases[0].pixels;var center=Vector3(p[0],p[1],p[2]);camera.position=center+Vector3(2,2,4);camera.look_at(center,Vector3.UP);camera.size=4.0
   for sample in reference.cases:
    var expected=Vector3(sample.pixels[0],sample.pixels[1],sample.pixels[2])
    if not original.custom_aabb.has_point(expected):failures.append("animated source vertex outside custom AABB")
  else:
   var blinks=source._floats(geometry.attributes.blink);var positions=source._vec3(geometry.attributes.position);var selected=-1
   for vertex in int(geometry.attributes.blink.count):
    if blinks[vertex*3]>0:selected=vertex;break
   if selected<0:selected=0;dynamic=false
   var first=int(selected/3)*3;var center=(positions[first]+positions[first+1]+positions[first+2])/3.0;var normal=(positions[first+1]-positions[first]).cross(positions[first+2]-positions[first]).normalized();var extent=maxf(positions[first].distance_to(positions[first+1]),positions[first].distance_to(positions[first+2]));camera.size=maxf(.1,extent*1.7);camera.position=center+normal*maxf(1.0,camera.size*2);camera.look_at(center,Vector3.FORWARD if absf(normal.dot(Vector3.UP))>.98 else Vector3.UP)
   if dynamic:
    var period=blinks[selected*3];var phase=blinks[selected*3+1];var duty=blinks[selected*3+2];times=[(ceilf(phase)-phase+.5)*period,(ceilf(phase)-phase+minf(.1,duty*.5))*period]
  var images=[]
  for time in times:
   material.set_shader_parameter("source_backdrop_time",time)
   for warm in 3:await process_frame;RenderingServer.force_draw(false)
   images.append(viewport.get_texture().get_image())
  var changed=0;var occupied=0;var maximum=0.0
  for y in 512:
   for x in 512:
    var a=images[0].get_pixel(x,y);var b=images[1].get_pixel(x,y);var delta=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);maximum=maxf(maximum,delta)
    if maxf(a.r,maxf(a.g,a.b))>.001 or maxf(b.r,maxf(b.g,b.b))>.001:occupied+=1
    if delta>.001:changed+=1
  if occupied<20 or (dynamic and changed<20):failures.append("actual backdrop geometry not visible/animated "+record.id)
  reports.append({"id":record.id,"name":record.name,"mode":mode,"attributes_exact":exact,"dynamic":dynamic,"occupied_pixels":occupied,"changed_pixels":changed,"maximum_rgb_difference":maximum,"times":times,"custom_aabb":str(original.custom_aabb)})
  if orbit:
   for index in 2:
    var image=images[index].duplicate();image.convert(Image.FORMAT_RGB8);image.save_png("res://evidence/backdrop-gulls-"+str(index)+".png")
 var report={"objects":reports,"clocks":clocks,"failures":failures,"scope":"Actual three original geometry/attributes andproduction Basic shader in isolated orthographic views. Full GPU custom-channel byte audit, orbit analytic AABB checkedagainst96 original vertices/times, visible motion/blink contributions. Actual Main independent backdrop clock with paused freeze and .05dt cap. Not full original perspective/bloom composition or alltime empirical culling proof."};FileAccess.open("res://evidence/backdrop-runtime-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));mesh.mesh=null;viewport.queue_free();await process_frame;game._dispose_game();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
