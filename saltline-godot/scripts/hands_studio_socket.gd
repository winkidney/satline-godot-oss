extends RefCounted
# Original Fh.socket / M5, including the left-hand reflection.
static func resolve(frame:Dictionary,position:Vector3,rotation:Quaternion,left:bool)->Transform3D:
 var p=position
 var q=rotation
 if left:p.x=-p.x;q=Quaternion(q.x,-q.y,-q.z,q.w)
 var result_q=q*Quaternion(frame.q[0],frame.q[1],frame.q[2],frame.q[3]).inverse()
 var result_p=p-result_q*Vector3(frame.p[0],frame.p[1],frame.p[2])
 if left:result_p.x=-result_p.x;result_q=Quaternion(result_q.x,-result_q.y,-result_q.z,result_q.w)
 return Transform3D(Basis(result_q),result_p)
