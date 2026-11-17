const fs=require('fs');
const text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const data=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json','utf8'));
class Vec {constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}distanceToSquared(v){return (this.x-v.x)**2+(this.y-v.y)**2+(this.z-v.z)**2}clone(){return new Vec(this.x,this.y,this.z)}toJSON(){return [this.x,this.y,this.z]}}
const start=text.indexOf('function su(n = 1337)');const create=eval('('+text.slice(start,text.indexOf('\n  var Hn =',start)).trim()+')');
const begin=text.indexOf('function jS(n, e, t, i)');const extract=(from,to)=>{let i=text.indexOf(from,begin);return text.slice(i,text.indexOf(to,i)).trim()};
const c0=data.modules.enemies.TUNE.hound,o=create(9001),Oo=new Vec(),G1=new Vec();
const O5=(a,b)=>{let x=(a-b)%(Math.PI*2);return x>Math.PI?x-Math.PI*2:x< -Math.PI?x+Math.PI*2:x};
let shots=0,melee=0,telegraphs=0,randomIndex=0;
const nav={isWalkable:(x,z)=>Math.abs(x)<29&&Math.abs(z)<29,randomPoint:(p,r)=>{let a=(randomIndex++%7)*.8;return new Vec(p.x+Math.cos(a)*12,0,p.z+Math.sin(a)*12)},findPath:(a,b)=>[b.clone()]};
const player={pos:new Vec(0,0,12),eye:new Vec(0,1.68,12),alive:true,damage:()=>melee++};
const s={player,physics:{nav,lineOfSight:(a,b)=>a.x<15,groundHeight:()=>0},level:{coverPoints:[new Vec(0,0,0),new Vec(10,0,8),new Vec(-9,0,5),new Vec(20,0,10)]},events:{emit:(event)=>{if(event==='enemy:telegraph')telegraphs++}}};
const g={id:1,type:'hound',active:true,alive:true,pos:new Vec(),headPos:new Vec(0,1,0),fwd:new Vec(),sensor:new Vec(),goal:new Vec(),firePos:new Vec(),firePlayer:new Vec(),lastKnown:new Vec(0,0,4),home:new Vec(),hasGoal:false,path:null,wp:0,planT:0,stuckT:0,yaw:0,wantYaw:0,speed:0,maxSpeed:0,cool:0,lungeCd:0,mode:'engage',modeSeen:'engage',es:'aim',esT:0,moveT:0,bursts:0,shots:0,tyaw:0,los:true,noSeeT:0,flare:0,sP:{v:0},waitT:0,scan:0,patrolR:8,patrolLine:null,hasToken:false};
const neighbor={id:2,type:'hound',alive:true,mode:'engage',es:'move',pos:new Vec(9,0,7),firePos:new Vec(10,0,8)};
const n={t:0,list:[g,neighbor],think:()=>{},requestToken:()=>{g.hasToken=true;return true},releaseToken:()=>{g.hasToken=false}};
const M=eval('('+extract('function M(k, C) {','function _() {')+')');const _=eval('('+extract('function _() {','function T(k, C) {')+')');const T=eval('('+extract('function T(k, C) {','function w() {')+')');const w=eval('('+extract('function w() {','function S(k) {')+')');const R=()=>shots++;
const si=text.indexOf('function S(k) {',begin),end=text.indexOf('let W = O5(g.wantYaw, g.yaw)',si);const decide=eval('('+text.slice(si,end)+'return {crouch:N,lunging:Z};})');
const selections=[];for(let i=0;i<30;i++){w();selections.push({firePos:g.firePos.toJSON(),goal:g.goal.toJSON(),es:g.es,esT:g.esT,moveT:g.moveT,bursts:g.bursts});}
const frames=[];
for(let frame=0;frame<900;frame++){
 if(frame%150===0){g.es='aim';g.esT=0;g.cool=0;g.lungeCd=0;g.mode='engage';g.modeSeen='engage';player.pos.set(0,0,frame%300===0?1:12);g.yaw=0;g.tyaw=0;g.los=true;}
 if(frame===600){g.mode='investigate';g.modeSeen='investigate';g.lastKnown.set(0,0,1);}
 if(frame===750){g.mode='patrol';g.modeSeen='patrol';g.hasGoal=false;}
 n.t+=1/60;const result=decide(1/60);let row={...result,shots,melee,telegraphs};for(let key of ['es','esT','mode','wantYaw','maxSpeed','cool','lungeCd','speed','yaw','flare','hasGoal','moveT','bursts','hasToken','waitT','scan','planT','wp'])row[key]=g[key];row.spring=g.sP.v;row.firePos=g.firePos.toJSON();row.goal=g.goal.toJSON();frames.push(row);
}
const aimStart=text.indexOf('let j = Math.cos(g.yaw)',si),aimEnd=text.indexOf('I(k);',aimStart);
const aim=eval('(function(k,F,H,N){g.crouch+=(N-g.crouch)*(1-Math.exp(-12*k));'+text.slice(aimStart,aimEnd).replace(/,\s*$/,';')+'})');
g.crouch=0;g.sY={x:0};g.phase=.37;g.yawRate=.3;g.tpitch=0;g.hyaw=0;g.hpitch=0;g.tyaw=0;
const bo=(v,a,b)=>Math.min(b,Math.max(a,v)),Yn={stand:.72},aimFrames=[];
for(let frame=0;frame<180;frame++){n.t=frame/60;g.yaw=Math.sin(frame*.02);const F=frame<120?new Vec(4,0,8):null,H=frame<60?new Vec(-2,0,3):null;aim(1/60,F,H,frame<90?.16:0);const row={};for(let key of ['crouch','scan','tyaw','tpitch','hyaw','hpitch'])row[key]=g[key];aimFrames.push(row);}
fs.writeFileSync('saltline-godot/assets/export/fixtures/hound-behavior-reference.json',JSON.stringify({scope:'Actual original w and S decision block with controlled nav, LOS, perception, token grant and fixed body position; shot callback counted, not ballistic simulation',selections,frames,aimFrames}));console.log({selections:selections.length,frames:frames.length,shots,melee,telegraphs,states:[...new Set(frames.map(x=>x.es))]});
