extends SceneTree
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func _initialize()->void:
 var reference=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hud-projection-reference.json"))
 var failures=[];var max_pixel=0.0;var max_float=0.0;var comparisons=0;var offscreen=0;var dim=0;var near_count=0
 for index in reference.cases.size():
  var row=reference.cases[index];var a=row.view
  var view=Transform3D(Basis(Vector3(a[0],a[1],a[2]),Vector3(a[4],a[5],a[6]),Vector3(a[8],a[9],a[10])),Vector3(a[12],a[13],a[14]))
  max_float=maxf(max_float,absf(SaltlineHudProjection.heading(row.yaw)-row.heading));comparisons+=1
  comparisons+=1
  if SaltlineHudProjection.tape_offset(row.yaw,row.compassWidth)!=row.tape:failures.append("%d tape"%index)
  var cross=SaltlineHudProjection.crosshair(row.ads,row.alive,row.state,row.spread,row.fov,row.size[1],row.sprinting)
  if cross.visible!=row.cross:failures.append("%d cross"%index)
  comparisons+=1
  if row.gap!=null:
   comparisons+=1
   if cross.gap!=row.gap:failures.append("%d gap"%index)
  for marker in row.markers:
   var result=SaltlineHudProjection.marker(vec(marker.pos),marker.kind,vec(row.player),row.yaw,view,row.fov,row.near,row.far,Vector2(row.size[0],row.size[1]),row.compassWidth)
   for key in ["distance","compass","edge","x","y","offscreen","near","dim"]:
    comparisons+=1
    if key in ["x","y"]:
     var error=absf(result[key]-marker[key]);max_pixel=maxf(max_pixel,error)
     if error>1:failures.append("%d %s %s"%[index,key,str(result)])
    elif result[key]!=marker[key]:failures.append("%d %s"%[index,key])
   offscreen+=int(result.offscreen);dim+=int(result.dim);near_count+=int(result.near)
 var report={"cases":reference.cases.size(),"markers":reference.cases.size()*4,"comparisons":comparisons,"failures":failures,"maximum_pixel_error":max_pixel,"maximum_heading_error":max_float,"offscreen":offscreen,"dim":dim,"near":near_count,"scope":"Actual original HUD compass/marker/crosshair block using original Three r180 projection vs native float32 transforms; pixel rounding tolerance 1, classifications exact; varied FOV, pitch, roll, aspect, ADS and sprint"}
 var file=FileAccess.open("res://evidence/hud-projection-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
