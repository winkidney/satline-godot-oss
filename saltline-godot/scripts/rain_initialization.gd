extends RefCounted
# Original Gw/Vw construction. Float32 assignment precedes eave sentinel writes.
static func generate(seed:int,rain_scale:float)->Dictionary:
 var rng=SaltlineSourceRng.new(seed)
 var scale=maxf(.15,rain_scale if rain_scale!=0 else .5)
 var drops=int(floor(9000*scale+.5));var splashes=int(floor(900*scale+.5))
 var rain=PackedFloat32Array();rain.resize((drops+260)*4)
 for i in rain.size():rain[i]=rng.randf()
 for i in range(drops,drops+260):rain[i*4+3]=-1
 var splash=PackedFloat32Array();splash.resize(splashes*4)
 for i in splash.size():splash[i]=rng.randf()
 var timer=22+rng.randf()*25
 return {"rain":rain,"splash":splash,"drops":drops,"eaves":260,"splashes":splashes,"thunder_timer":timer,"calls":rng.calls,"state":rng.state}
