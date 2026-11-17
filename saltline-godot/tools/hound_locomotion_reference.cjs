async(page)=>await page.evaluate(async()=>{
 const T=__G.THREE,text=await(await fetch('/source/extracted/bundle-1.js')).text();__G.explosives.reset();
 const begin=text.indexOf('function jS(n, e, t, i)');const extract=(from,to)=>{const i=text.indexOf(from,begin);return text.slice(i,text.indexOf(to,i)).trim()};
 const createStart=text.indexOf('function su(n = 1337)');const create=eval('('+text.slice(createStart,text.indexOf('\n  var Hn =',createStart)).trim()+')');
 const c0=__G.enemies.TUNE.hound,o=create(9001),s={physics:__G.physics};
 const Oo=new T.Vector3(),Ho=new T.Vector3();
 const bo=(x,lo,hi)=>Math.min(hi,Math.max(lo,x)),O5=(a,b)=>{let x=(a-b)%(Math.PI*2);return x>Math.PI?x-Math.PI*2:x< -Math.PI?x+Math.PI*2:x};
 const g={id:1,type:'hound',active:true,pos:new T.Vector3(-32,0,6),goal:new T.Vector3(),hasGoal:false,path:null,wp:0,planT:0,stuckT:0,feelT:0,blocked:false,yaw:0,speed:0,prevSpeed:0,yawRate:0,wantYaw:0,maxSpeed:0,push:new T.Vector3(),phase:.37,mode:'patrol',es:'move',esT:0};
 const wreck={id:2,type:'hound',active:true,alive:false,pos:new T.Vector3(-31.4,0,6.8)};const n={list:[g,wreck]};let reposition=0;const w=()=>reposition++;
 const M=eval('('+extract('function M(k, C) {','function _() {')+')');const replan=eval('('+extract('function _() {','function T(k, C) {')+')');const _=replan;const follow=eval('('+extract('function T(k, C) {','function w() {')+')');
 const moveStart=text.indexOf('let W = O5(g.wantYaw, g.yaw)',begin);const moveEnd=text.indexOf('z(k),',moveStart);const body=text.slice(moveStart,moveEnd).replace(/,\s*$/,';');const move=eval('(function(k){const Z=false,C=null,Q=1e9;'+body+'})');
 const frames=[];M(new T.Vector3(-24,0,6),true);
 for(let frame=0;frame<720;frame++){
  const arrived=follow(1/60,3.4);move(1/60);
  frames.push({pos:g.pos.toArray(),yaw:g.yaw,yawRate:g.yawRate,speed:g.speed,maxSpeed:g.maxSpeed,push:g.push.toArray(),planT:g.planT,wp:g.wp,hasGoal:g.hasGoal,blocked:g.blocked,arrived});
 }
 const result={source:'Original Hound M/_/T and exact movement block; real world nav/rays and nearby active wreck',frames};const response=await fetch('http://127.0.0.1:8794/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'fixtures/hound-locomotion-reference.json',json:result})});if(!response.ok)throw Error(await response.text());return {frames:frames.length,arrived:frames.at(-1).arrived,reposition,errors:__errors};
})
