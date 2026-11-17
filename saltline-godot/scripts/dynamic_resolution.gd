extends RefCounted

var state={"scale":1.0,"enabled":true,"acc":0.0,"n":0,"settle":3.5,"upWait":4.0,"upDelay":4.0}

# Direct numeric port of the original render R(G). Events are consumed synchronously.
func sample(milliseconds:float,quality:String,post_available:bool=true)->Array:
 var events=[];var s=state
 if not s.enabled or not post_available or milliseconds>1500:return events
 s.settle-=milliseconds/1000;s.upWait-=milliseconds/1000
 if s.settle>0:s.acc=0.0;s.n=0;return events
 s.acc+=milliseconds;s.n+=1
 if s.n<45 and s.acc<900:return events
 var mean=float(s.acc)/s.n;s.acc=0.0;s.n=0
 var scale=float(s.scale)
 if mean>21.5 and scale>.6:
  scale=.6 if mean>45 else maxf(.6,scale-(.2 if mean>30 else .1))
  s.upDelay=minf(60,s.upDelay*2);s.upWait=s.upDelay
 elif mean<17.4 and scale<1 and s.upWait<=0:scale=minf(1,scale+.1);s.upWait=2.0
 elif mean<17.4 and scale>=1:s.upDelay=4.0
 scale=floor(scale*10+.5)/10
 if scale<=.6 and mean>26:
  s.floorHits=s.get("floorHits",0)+1
  var lower={"ultra":"high","high":"medium","medium":"low"}.get(quality,"")
  if s.floorHits>=2 and not lower.is_empty():
   s.floorHits=0;s.scale=.8;s.settle=2.0;s.upDelay=4.0
   events.append({"kind":"quality","name":lower});events.append({"kind":"auto","name":lower});return events
 else:s.floorHits=0
 if scale!=s.scale:s.scale=scale;s.settle=1.0;events.append({"kind":"resize"})
 return events
