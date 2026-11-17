class_name SaltlineWeaponMotionMath
extends RefCounted
# Original pn/en/Xn/AE/sa/ry, bundle-1.js 72783 onward. CPU doubles.
static func spring(frequency:float,damping:float=1.0)->Dictionary:
 return {"x":0.0,"v":0.0,"w":frequency,"z":damping}
static func reset(state:Dictionary,value:float=0.0)->void:
 state.x=value;state.v=0.0
static func advance(state:Dictionary,target:float,dt:float,frequency:float=-1.0,damping:float=-1.0)->float:
 var w=float(state.w) if frequency<0.0 else frequency;var z=float(state.z) if damping<0.0 else damping;var offset=float(state.x)-target;var velocity=float(state.v)
 # Source treats z>=.999 as critical; do not replace with overdamped physics.
 if z>=.999:
  var decay=exp(-w*dt);var linear=velocity+w*offset;state.x=target+(offset+linear*dt)*decay;state.v=(velocity-w*linear*dt)*decay
 else:
  var wd=w*sqrt(1.0-z*z);var decay=exp(-z*w*dt);var cosine=cos(wd*dt);var sine=sin(wd*dt);var phase=(velocity+z*w*offset)/wd
  state.x=target+decay*(offset*cosine+phase*sine);state.v=decay*(wd*(phase*cosine-offset*sine)-z*w*(offset*cosine+phase*sine))
 return state.x
static func ease(value:float)->float:
 var n=clampf(value,0.0,1.0);return n*n*n*(n*(6.0*n-15.0)+10.0)
static func hash_noise(value:float)->float:
 var x=sin(value*127.1+311.7)*43758.5453;return (x-floor(x))*2.0-1.0
static func noise(value:float,seed:float=0.0)->float:
 var cell=floor(value);var phase=value-cell;var weight=phase*phase*phase*(phase*(6.0*phase-15.0)+10.0)
 return 2.0*((1.0-weight)*hash_noise(cell+seed*57.31)*phase+weight*hash_noise(cell+1.0+seed*57.31)*(phase-1.0))
static func soft_limit(value:float,limit:float)->float:
 return limit*tanh(value/limit)
