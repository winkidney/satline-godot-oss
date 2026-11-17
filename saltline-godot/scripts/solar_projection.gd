class_name SaltlineSolarProjection
extends RefCounted

static func project(camera:Camera3D,direction:Vector3)->Dictionary:
 var size=Vector2(camera.get_viewport().get_visible_rect().size)
 var pixel=camera.unproject_position(camera.global_position+direction*500.0)
 var uv=Vector2(pixel.x/size.x,1.0-pixel.y/size.y)
 var ndc=uv*2.0-Vector2.ONE
 var front=(-camera.global_basis.z).dot(direction)>.05
 var edge=maxf(absf(ndc.x),absf(ndc.y))
 var on=1.0-clampf((edge-1.0)/.3,0.0,1.0) if front else 0.0
 return {"uv":uv,"on":on,"front":front,"edge":edge}
