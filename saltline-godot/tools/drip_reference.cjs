const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function _(')+section('    function G(j, O, q, ue, de, $, se)','    function te(')+section('    function oe(j) {','    n.events.on("impact",')+section('    function S(j, O, q, ue, de, $, se, fe, me) {','    function R(')+section('  function go(n, e, t) {','  async function f1(');

const tape=Array.from({length:131072},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const operations=[];
function start(index,emitter_kind,ttl,scale=1,shade=1){operations.push({kind:'start',emitter_kind,position:[index*.25,.3,-index*.125],ttl,scale,shade});}
start(1,'drip','INF',1.3,.2);operations.at(-1).position=[.4,.05,1.6];
const minFall=Math.sqrt(2*.05/9.81);
for(const dt of [.625,1e-8,minFall,0,1e-10])operations.push({kind:'update',dt});
operations.push({kind:'position',slot:0,position:[.4,2.6,1.6]});
operations.push({kind:'update',dt:.7},{kind:'position',slot:0,position:[1.1,2.6,-.8]});for(const dt of [.2,.5,.6])operations.push({kind:'update',dt});
operations.push({kind:'stop',slot:0});start(4,'drip',1.2,2,.8);operations.at(-1).position=[3.25,-.25,-.5];
for(const dt of [.7,minFall,.000001,.5])operations.push({kind:'update',dt});operations.push({kind:'clear'});
for(let i=0;i<25;i++){start(i,['drip','steam','embers','smolder'][i%4],i===0?.125:1+i*.1,.4+i*.05,i%2?1:.2);operations.at(-1).position[1]=i%2?2.6:0;}
for(const dt of [.125,.00001,.5,.75])operations.push({kind:'update',dt});
operations.push({kind:'clear_particles'},{kind:'update',dt:.2},{kind:'clear'});start(40,'drip',.5);operations.push({kind:'update',dt:.5},{kind:'update',dt:.000001});
const lightStart=s.indexOf('    let v = {',s.indexOf('let m = 6,'));let cursor=s.indexOf('{',lightStart)+1,depth=1;while(depth){if(s[cursor]==='{')depth++;if(s[cursor]==='}')depth--;cursor++;}const lightMethods=s.slice(s.indexOf('{',lightStart),cursor);
const emitterConstructor=section('    let W = [];\n    for (let j = 0; j < 24; j++) {','    let J = {');
const cases=[];
for(const capacity of [2,256])for(const light_capacity of [0]){
 const l=new Pool(capacity,true),c=new Pool(capacity,false),W=Function('K',emitterConstructor+'return W;')(T.Vector3),J={active:false,pos:new T.Vector3()};
 const lightSlots=Array.from({length:light_capacity},()=>{const light=new T.PointLight(0xffffff,0,12,2);light.userData={busy:false,persistent:false,ttl:0,dur:0,peak:0};return light});const lightPool=Function('x','return ('+lightMethods+');')(lightSlots);
 const factory=Function('Et','lt','l','c','W','J','mo','Gg','y','Hv','fh','dh','Ri','st',methods+'return {start:G,update:oe};'),api=factory(M.random,(a,b)=>a+(b-a)*M.random(),l,c,W,J,0,5,()=>lightPool,4,6,2,new T.Vector3(0,1,0),new T.Vector3()),rows=[];
 for(const op of operations){let result=null;
  if(op.kind==='start'){const handle=api.start(...op.position,op.emitter_kind,op.ttl==='INF'?Infinity:op.ttl,op.scale,op.shade);result=W.indexOf(handle);}
  else if(op.kind==='update')api.update(op.dt>0?op.dt:0);
  else if(op.kind==='position')W[op.slot].setPos(new T.Vector3(...op.position));
  else if(op.kind==='stop')W[op.slot].stop();
  else if(op.kind==='clear_particles'){l.clear();c.clear();}
  else {l.clear();c.clear();for(const e of W)e.stop();}
  rows.push({op,expected:{result,calls,slots:W.map((e,index)=>({index,active:e.active,light_index:e.light?lightSlots.indexOf(e.light.light):-1,...(e.active?{kind:e.kind,position:e.pos.toArray(),time:e.t,ttl:Number.isFinite(e.ttl)?e.ttl:'INF',scale:e.scale,shade:e.shade,accumulator:e.acc,accumulator2:e.acc2,drop:e.drop}:{})})),lights:lightSlots.map(light=>({busy:light.userData.busy,persistent:light.userData.persistent,intensity:light.intensity,distance:light.distance,position:light.position.toArray(),color:light.color.toArray()})),particles:snapshot(l),add_particles:snapshot(c)}});
 }
 cases.push({capacity,light_capacity,rows});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/drip-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods+emitterConstructor+lightMethods).digest('hex')}));console.log(JSON.stringify({cases:cases.length,steps:operations.length,calls}));
