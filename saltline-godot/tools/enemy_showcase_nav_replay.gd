extends "res://scripts/navigation.gd"

var tape:Array=[]
var cursor=0
var maximum_origin_error=0.0
var failures:Array=[]

func random_point(origin:Vector3,radius:float)->Vector3:
 if cursor>=tape.size():
  failures.append("original navigation tape exhausted");return origin
 var row=tape[cursor];cursor+=1
 maximum_origin_error=maxf(maximum_origin_error,origin.distance_to(Vector3(row.from[0],row.from[1],row.from[2])))
 if absf(radius-float(row.radius))>.00001:failures.append("navigation radius mismatch")
 return Vector3(row.result[0],row.result[1],row.result[2])
