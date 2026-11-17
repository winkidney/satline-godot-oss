const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function _(')+section('    function G(j, O, q, ue, de, $, se)','    function te(')+section('    function oe(j) {','    n.events.on("impact",');

const tape=Array.from({length:32768},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const operations=[];
function start(index,ttl,scale=1,shade=1){operations.push({kind:'start',position:[index*.25,.3,-index*.125],ttl,scale,shade});}
for(let i=0;i<25;i++)start(i,i===0?.2:3+i*.01,.4+i*.05,i%2?1:.2);
operations.push({kind:'update',dt:.2},{kind:'update',dt:.00001});start(100,2,1.5,.2);
for(const dt of [.17,.15,.5,1,1.5])operations.push({kind:'update',dt});
operations.push({kind:'clear'});start(200,'INF',2,.2);
for(const dt of [0,1/9,0,1e-8,-.2,.13,.2])operations.push({kind:'update',dt});
operations.push({kind:'clear'});
for(let i=0;i<24;i++)start(i,.3+i*.1,1,.7);
for(const dt of [.3,.000001,.12])operations.push({kind:'update',dt});start(300,1,.8,1);
operations.push({kind:'clear_particles'},{kind:'update',dt:.2},{kind:'update',dt:.5},{kind:'clear'});start(400,.5,.4,.2);operations.push({kind:'update',dt:.5},{kind:'update',dt:.000001});
const cases=[];
for(const capacity of [2,256]){
 const l=new Pool(capacity,true),W=Array.from({length:24},()=>({active:false,kind:'steam',pos:new T.Vector3(),acc:0,acc2:0,ttl:Infinity,scale:1,shade:1,t:0,drop:-1,light:null,stop(){this.active=false;}})),J={active:false,pos:new T.Vector3()},factory=Function('Et','lt','l','W','J',methods+'return {start:G,update:oe};'),api=factory(M.random,(a,b)=>a+(b-a)*M.random(),l,W,J),rows=[];
 for(const op of operations){let result=null;
  if(op.kind==='start'){const handle=api.start(...op.position,'smolder',op.ttl==='INF'?Infinity:op.ttl,op.scale,op.shade);result=W.indexOf(handle);}
  else if(op.kind==='update')api.update(op.dt>0?op.dt:0);
  else if(op.kind==='clear_particles')l.clear();
  else {l.clear();for(const e of W)e.stop();}
  rows.push({op,expected:{result,calls,slots:W.map((e,index)=>({index,active:e.active,...(e.active?{position:e.pos.toArray(),time:e.t,ttl:Number.isFinite(e.ttl)?e.ttl:'INF',scale:e.scale,shade:e.shade,accumulator:e.acc}:{})})),particles:snapshot(l)}});
 }
 cases.push({capacity,rows});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/smolder-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods).digest('hex')}));console.log(JSON.stringify({cases:cases.length,steps:operations.length,calls}));
