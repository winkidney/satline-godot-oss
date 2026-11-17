extends SceneTree
func _initialize()->void:
 var frames=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/hands-showcase-sockets.json"))
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://assets/export/fixtures/hands-studio-sockets.json"))
 var maximum=0.0
 for row in fixture.cases:
  var p=row.input.p;var q=row.input.q
  var actual=preload("res://scripts/hands_studio_socket.gd").resolve(frames[row.name],Vector3(p[0],p[1],p[2]),Quaternion(q[0],q[1],q[2],q[3]),row.side=="l")
  p=row.expected.p;q=row.expected.q
  maximum=maxf(maximum,actual.origin.distance_to(Vector3(p[0],p[1],p[2])))
  maximum=maxf(maximum,1-absf(actual.basis.get_rotation_quaternion().dot(Quaternion(q[0],q[1],q[2],q[3]))))
 var report={"cases":fixture.cases.size(),"maximum":maximum,"passed":maximum<0.000001}
 FileAccess.open("res://evidence/hands-studio-socket-verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print(JSON.stringify(report));quit(0 if report.passed else 1)
