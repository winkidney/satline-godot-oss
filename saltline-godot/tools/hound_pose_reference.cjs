async(page)=>await page.evaluate(async()=>{
 const T=__G.THREE;const text=await(await fetch('/source/extracted/bundle-1.js')).text();const begin=text.indexOf('function jS(n, e, t, i)');
 const extract=(from,to)=>text.slice(text.indexOf(from,begin),text.indexOf(to,text.indexOf(from,begin))).trim();
 const usStart=text.indexOf('function US(n, e, t, i, s, o, r, a)');const US=eval('('+text.slice(usStart,text.indexOf('\n  var Bs =',usStart)).trim()+')');
 const llStart=text.indexOf('function ll(n, e, t, i, s)');const ll=eval('('+text.slice(llStart,text.indexOf('\n  function jS',llStart)).trim()+')');
 const Yn={stand:.72,L1:.4,L2:.42,l0:.075,hipX:.165,hipY:-.01,hipZ:.4,footX:.275,footZ:[.37,.37,-.42,-.42],legs:['FL','FR','RL','RR'],side:[1,-1,1,-1],fore:[1,1,-1,-1],footR:.046};
 const original=__G.enemies.debug.hounds[0];const group=original.rig.group.clone(true);const l={};group.traverse(node=>{if(node.isBone)l[node.name]=node});
 const a={group},c=Yn.legs.map(k=>l['abd'+k]),u=Yn.legs.map(k=>l['thigh'+k]),f=Yn.legs.map(k=>l['shin'+k]);
 let steps=0;const s={physics:{groundHeight:()=>0},events:{emit:()=>steps++}},n={t:0},_s=new T.Vector3(),B5={abd:0,hip:0,knee:0,reach:0},bo=(x,lo,hi)=>Math.min(hi,Math.max(lo,x));
 const b=Array.from({length:4},()=>({p:new T.Vector3(),from:new T.Vector3(),to:new T.Vector3()}));
 const g={pos:group.position,speed:0,prevSpeed:0,yaw:.4,yawRate:0,push:new T.Vector3(),sw:-1,swT:0,swDur:.2,lastPair:1,idleT:0,lift:.08,phase:.37,alive:true,crouch:0,tyaw:.2,tpitch:-.05,hpitch:.1,hyaw:-.3,headPos:new T.Vector3()};
 for(const key of ['sY','sP','sR','sL','sA','sA2'])g[key]={x:0,v:0};
 const V5=[[0,3],[1,2]];
 const E=eval('('+extract('function E(k, C, A, F, H)','function M(k, C)')+')');
 const step=eval('('+extract('function z(k) {','function I(k) {')+')');const pose=eval('('+extract('function I(k) {','function L(k) {')+')');
 g.pos.set(-30,0,8);for(let i=0;i<4;i++)E(b[i].p,i,g.pos.x,g.pos.z,g.yaw);pose(.016);
 const frames=[];
 for(let frame=0;frame<240;frame++){
  n.t=(frame+1)/60;g.prevSpeed=g.speed;g.speed=frame<120?Math.min(3,frame*.04):Math.max(0,3-(frame-120)*.05);g.yawRate=frame>=60&&frame<160?.45:0;g.yaw+=g.yawRate/60;g.pos.x+=Math.sin(g.yaw)*g.speed/60;g.pos.z+=Math.cos(g.yaw)*g.speed/60;
  step(1/60);pose(1/60);
  const bones={};for(const [name,node] of Object.entries(l)){node.updateMatrix();bones[name]=node.matrix.toArray()}
  frames.push({bones,feet:b.map(k=>k.p.toArray()),position:g.pos.toArray(),steps,sw:g.sw});
 }
 const response=await fetch('http://127.0.0.1:8794/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'fixtures/hound-pose-reference.json',json:{source:'Original Hound z/I/E/US/ll with real Three bones; controlled flat-ground motion',frames}})});if(!response.ok)throw Error(await response.text());return {frames:frames.length,bones:Object.keys(l).length,steps,errors:__errors};
})
