class_name SaltlinePlanarCamera
extends RefCounted

static func matrix(a:Array)->Projection:
 return Projection(Vector4(a[0],a[1],a[2],a[3]),Vector4(a[4],a[5],a[6],a[7]),Vector4(a[8],a[9],a[10],a[11]),Vector4(a[12],a[13],a[14],a[15]))

static func projection_transform(t:Transform3D)->Projection:
 return Projection(Vector4(t.basis.x.x,t.basis.x.y,t.basis.x.z,0),Vector4(t.basis.y.x,t.basis.y.y,t.basis.y.z,0),Vector4(t.basis.z.x,t.basis.z.y,t.basis.z.z,0),Vector4(t.origin.x,t.origin.y,t.origin.z,1))

# Input projection uses the original Three/OpenGL depth convention, before Vulkan correction.
static func compute(world:Transform3D,projection:Projection,resolution:Vector2i,scale:float,enabled:bool=true,far_z:float=900.0)->Dictionary:
 if not enabled or scale<=0.0 or world.origin.y<Vector3(0,.03,0).y:return {"active":false}
 var position=world.origin;position.y=-position.y
 var direction=-world.basis.z;direction.y=-direction.y
 var up=world.basis.y;up.y=-up.y
 var reflected=Transform3D(Basis.looking_at(direction,up),position)
 var view=projection_transform(reflected.affine_inverse())
 var bias=Projection(Vector4(.5,0,0,0),Vector4(0,.5,0,0),Vector4(0,0,.5,0),Vector4(.5,.5,.5,1))
 var sampling=bias*projection*view
 var normal=reflected.basis.transposed()*Vector3.UP
 # Keep oblique plane scaling in scalar float64; Vector4 arithmetic is float32.
 var px=float(normal.x);var py=float(normal.y);var pz=float(normal.z);var pw=.01+float(reflected.origin.y)
 var qx=(signf(px)+float(projection.z.x))/float(projection.x.x)
 var qy=(signf(py)+float(projection.z.y))/float(projection.y.y)
 var qw=1.0/far_z # Algebraically identical for source perspective; avoids float32 cancellation.
 var factor=2.0/(px*qx+py*qy-pz+pw*qw)
 var clipped=projection
 clipped.x.z=px*factor;clipped.y.z=py*factor;clipped.z.z=pz*factor+1.0;clipped.w.z=pw*factor
 var size=Vector2i(maxi(64,int(floor(resolution.x*scale/16.0+.5))*16),maxi(32,int(floor(resolution.y*scale/8.0+.5))*8))
 return {"active":true,"world":reflected,"projection":clipped,"sampling":sampling,"size":size,"scale":Vector2(projection.x.x*.5,projection.y.y*.5),"lod":log(float(size.y)/270.0)/log(2.0)}
