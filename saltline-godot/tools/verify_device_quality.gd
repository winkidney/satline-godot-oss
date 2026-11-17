extends SceneTree
func _initialize()->void:
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/device-quality.json"))
 var failures=[]
 for row in fixture.cases:
  var result=preload("res://scripts/device_quality.gd").choose(row.requested,row.user_agent,row.touch_points,Vector2i(row.screen[0],row.screen[1]),row.renderer)
  if result!=row.expected:failures.append(row)
 var ios=preload("res://scripts/device_quality.gd").native_user_agent("iOS")
 if preload("res://scripts/device_quality.gd").choose("",ios,0,Vector2i(1920,1080),"Apple GPU")!="low":failures.append("native iOS mapping")
 var report={"cases":fixture.cases.size(),"failures":failures,"native":preload("res://scripts/device_quality.gd").detect(),"scope":"Literal UM predicate comparison with supplied device descriptors, native adapter separately reports unknown desktop maxTouchPoints."}
 FileAccess.open("res://evidence/device-quality-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
