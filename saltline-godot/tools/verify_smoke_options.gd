extends SceneTree
class Probe:
 extends SaltlineImpactEffects
 var rows=[]
 func shade_at(_p:Vector3,_n:Vector3)->float:return .2
 func puff(p:Vector3,v:Vector3,life:float,start:float,end:float,_color:Vector3,alpha:float,_shade:float,_drag:float,rise:float,_wind:float,_frame:int=-1)->Dictionary:
  rows.append([p.x,p.y,p.z,v.x,v.y,v.z,life,start,end,alpha,rise]);return {}
func _initialize()->void:
 var fixtures=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/smoke-options-reference.json"))
 var failures=[];var checks=0;var maximum=0.0
 for fixture in fixtures:
  var fx=Probe.new();fx.rng=preload("res://scripts/fx_random.gd").new(fixture.tape)
  fx.smoke(Vector3(1,2,3),fixture.options)
  if fx.rows.size()!=fixture.rows.size():failures.append(fixture.name+": count")
  if fx.rng.calls!=fixture.draws:failures.append(fixture.name+": draws")
  for i in mini(fx.rows.size(),fixture.rows.size()):
   for j in fx.rows[i].size():
    checks+=1;var error=absf(fx.rows[i][j]-fixture.rows[i][j]);maximum=maxf(maximum,error)
    if error>0.000001:failures.append(fixture.name+": value "+str(i)+"/"+str(j))
  fx.free()
 var result={"checks":checks,"cases":fixtures.size(),"maximum_error":maximum,"failures":failures}
 var file=FileAccess.open("res://evidence/smoke-options-verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
