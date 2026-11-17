const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('  function go(n, e, t)','  async function f1(n)')+section('    function _(j, O, q, ue, de, $, se, fe, me, ge, ce, P)','    function S(');

const tape=Array.from({length:32768},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const cases=[];
for(const capacity of [0,1,2,7,12,15,80])for(const count of [2,9,18]){
 const c=new Pool(capacity,false),before=calls;
 const fn=Function('Math','Et','lt','c','st','Bv',methods+'return {sparks:T,flash:w};')(M,M.random,(a,b)=>a+(b-a)*M.random(),c,new T.Vector3(),1);
 const rows=[];for(let i=0;i<3;i++){if(i===2)c.clear();fn.sparks(new T.Vector3(3,-1.6,2),new T.Vector3(0,1,0),count,6,24,.55,.1,.38,40,25,10.5,1);fn.flash(3,-1.6,2,.05,.25,.45,16,11,5.5,0);fn.flash(3,-1.6,2,.04,.35,.5,9,6,2.6,2+(M.random()*2|0));rows.push({calls,pools:{add:snapshot(c),lit:[]}});}
 cases.push({capacity,count,before,rows});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/sparks-random-reference.json'),JSON.stringify({tape,tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods).digest('hex')}));console.log(JSON.stringify({cases:cases.length,calls}));
