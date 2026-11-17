class_name SaltlineEnemyCoordinator
extends RefCounted

signal alerted(enemy:Dictionary)
var tuning:Dictionary
var physics:SaltlinePhysics
var player:Variant
var rng:SaltlineSourceRng
var list:Array=[]
var time=0.0
var tokens=0
var token_time=-9.0
var last_type=""
var want_times={"gull":-9.0,"hound":-9.0}

func _init(settings:Dictionary,collision:SaltlinePhysics,avatar:Variant,random_stream:SaltlineSourceRng=null)->void:
 tuning=settings;physics=collision;player=avatar;rng=random_stream if random_stream!=null else SaltlineSourceRng.new(9001)

func request_token(enemy:Dictionary)->bool:
 if enemy.hasToken:return true
 var alive=0
 for other in list:
  if other.alive:alive+=1
 var capacity=int(tuning.maxTokensCrowd if alive>5 else tuning.maxTokens)
 var elapsed=time-token_time
 var opposite="hound" if enemy.type=="gull" else "gull"
 var alternate=last_type==enemy.type and time-want_times[opposite]<.5 and elapsed<tuning.tokenGap*2.2
 if tokens>=capacity or elapsed<tuning.tokenGap or alternate:
  want_times[enemy.type]=time;return false
 tokens+=1;token_time=time;last_type=enemy.type;enemy.hasToken=true;return true

func release_token(enemy:Dictionary)->void:
 if enemy.hasToken:enemy.hasToken=false;tokens=maxi(0,tokens-1)

func think(enemy:Dictionary,dt:float,notice_delay:float)->void:
 if enemy.passive or player==null:enemy.los=false;return
 enemy.senseT-=dt
 if enemy.senseT<=0:
  enemy.senseT=.11+rng.randf()*.08
  var visible=false
  if player.alive:
   var delta:Vector3=player.eye-enemy.sensor
   var distance=delta.length()
   if distance<tuning.sightRange:
    var horizontal=maxf(Vector2(delta.x,delta.z).length(),.0001)
    var facing=(delta.x*enemy.fwd.x+delta.z*enemy.fwd.z)/horizontal
    if enemy.mode=="engage" or facing>cos(deg_to_rad(tuning.sightCone*.5)) or distance<3.5:
     visible=physics.line_of_sight(enemy.sensor,player.eye)
  enemy.los=visible
 if enemy.los:
  enemy.seeT+=dt;enemy.noSeeT=0;enemy.lastKnown=player.pos
  enemy.exposure=minf(1,enemy.exposure+dt*tuning.exposureUp)
 else:
  enemy.noSeeT+=dt;enemy.seeT=maxf(0,enemy.seeT-dt*.6)
  enemy.exposure=maxf(0,enemy.exposure-dt*tuning.exposureDown)
 if enemy.mode=="engage":
  if enemy.noSeeT>tuning.loseSight or not player.alive:
   enemy.mode="search";enemy.modeT=tuning.searchTime+rng.randf()*3;release_token(enemy)
 elif enemy.los and enemy.seeT>(notice_delay if enemy.mode=="patrol" else notice_delay*.45):
  enemy.mode="engage";enemy.noSeeT=0;alerted.emit(enemy);rally(enemy.pos,18,player.pos,enemy)
 elif enemy.mode!="patrol":
  enemy.modeT-=dt
  if enemy.modeT<=0:enemy.mode="patrol";enemy.home.x=enemy.pos.x;enemy.home.z=enemy.pos.z

func rally(position:Vector3,radius:float,target:Vector3,source:Dictionary={})->void:
 for enemy in list:
  if (not source.is_empty() and enemy.id==source.id) or not enemy.alive or enemy.passive or enemy.mode=="engage" or enemy.pos.distance_squared_to(position)>radius*radius:continue
  enemy.lastKnown=target;enemy.mode="investigate";enemy.modeT=9+rng.randf()*4

func provoke(enemy:Dictionary)->void:
 if player==null or enemy.passive or not enemy.alive:return
 if enemy.mode!="engage":
  enemy.lastKnown=player.pos;enemy.mode="investigate";enemy.modeT=10;enemy.seeT=1;enemy.senseT=0
 rally(enemy.pos,20,player.pos,enemy)
