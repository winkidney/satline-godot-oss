async(page)=>await page.evaluate(async()=>{
 const g=__G,T=g.THREE,Bi=g.enemies.TUNE,$D=Math.cos(Bi.sightCone/2*Math.PI/180);
 const source=await(await fetch('/source/extracted/bundle-1.js')).text();const start=source.indexOf('function su(n = 1337)');const end=source.indexOf('\n  var Hn =',start);const createRng=eval('('+source.slice(start,end).trim()+')');
 let t=[],f={},e=createRng(9001),clear=true;const n={player:{alive:true,pos:new T.Vector3(),eye:new T.Vector3(0,1.68,0)},physics:{lineOfSight:()=>clear},events:{emit:()=>{}}};
 const names=['requestToken','releaseToken','think','rally','provoke'];
 const methods=eval('({'+names.map(name=>g.enemies.debug.ctx[name].toString()).join(',')+'})');
 function reset(){t=[];f={...methods,t:0,tokens:0,tokenT:-9,lastType:'',wantT:{gull:-9,hound:-9}};e=createRng(9001)}
 function enemy(id,type,pos,alive=true,passive=false){return {id,type,pos:new T.Vector3(...pos),alive,passive,hasToken:false,sensor:new T.Vector3(pos[0],1,pos[2]),fwd:new T.Vector3(0,0,1),senseT:0,los:false,seeT:0,noSeeT:0,exposure:0,mode:'patrol',modeT:0,lastKnown:new T.Vector3(),home:new T.Vector3(...pos)}}
 reset();for(let i=0;i<8;i++)t.push(enemy(i,i%2?'hound':'gull',[i,0,-8],i<4));
 const operations=[[0,'request',0],[.5,'request',1],[1.3,'request',2],[1.4,'request',1],[2.7,'request',3],[2.8,'release',0],[2.8,'request',3],[3,'crowd',0],[3,'request',4],[4.1,'request',4],[5.5,'request',5],[5.6,'release',2],[5.6,'request',6],[5.7,'request',5]];
 const tokenCases=[];
 for(const [time,operation,id] of operations){f.t=time;let result=null;if(operation==='request')result=f.requestToken(t[id]);else if(operation==='release')f.releaseToken(t[id]);else for(const entity of t)entity.alive=true;tokenCases.push({time,operation,id,result,tokens:f.tokens,flags:t.map(k=>k.hasToken),want:{...f.wantT},lastType:f.lastType})}
 reset();t.push(enemy(1,'hound',[0,0,-8]),enemy(2,'gull',[4,0,-8]),enemy(3,'hound',[-3,0,-8],true,true));
 const perception=[];
 for(let frame=0;frame<360;frame++){
  f.t=(frame+1)*.05;clear=frame<20;n.player.alive=frame<120||frame>=180;
  if(frame===15){t[0].hasToken=true;f.tokens=1}
  if(frame===180)f.provoke(t[0]);if(frame===280){t[0].mode='investigate';t[0].modeT=.1}
  f.think(t[0],.05,.35);
  const k=t[0];perception.push({mode:k.mode,modeT:k.modeT,los:k.los,senseT:k.senseT,seeT:k.seeT,noSeeT:k.noSeeT,exposure:k.exposure,lastKnown:k.lastKnown.toArray(),home:k.home.toArray(),hasToken:k.hasToken,tokens:f.tokens,neighborMode:t[1].mode,neighborTime:t[1].modeT,passiveMode:t[2].mode});
 }
 const output={source:'Original active enemy ctx methods; fresh su(9001); controlled LOS',tokenCases,perception};const response=await fetch('http://127.0.0.1:8794/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'fixtures/enemy-coordinator-reference.json',json:output})});if(!response.ok)throw Error(await response.text());return {tokenCases:tokenCases.length,perceptionFrames:perception.length,errors:__errors};
})
