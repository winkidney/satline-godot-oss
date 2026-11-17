const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('  function go(n, e, t)','  async function f1(n)')+section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function _(')+section('    function S(j, O, q, ue, de, $, se, fe, me)','    function R(')+section('    function k(j, O = 1)','    let C = { p: new K() };');
const tape=Array.from({length:32768},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const cases=[];
for(const capacity of [0,1,2,7,12,15,80])for(const size of [.4,1,2]){
 const l=new Pool(capacity,true),c=new Pool(capacity,false),before=calls;
 const k=Function('Math','Et','lt','l','c','Ri','st','g','dh','fh','Hv',methods+'return k;')(M,M.random,(a,b)=>a+(b-a)*M.random(),l,c,new T.Vector3(0,1,0),new T.Vector3(),()=>1,2,6,4);
 const rows=[];for(let i=0;i<3;i++){if(i===2){l.clear();c.clear();}k(new T.Vector3(3,-1.6,2),size);rows.push({calls,pools:{lit:snapshot(l),add:snapshot(c)}});}
 cases.push({capacity,size,before,rows});
}
const scatter=[];
for(const rawValues of [[.5,.5,.5,.25],[.5000000001,.5,.5,.75],[.5,.4999999999,.5,.5],[0,1-Number.EPSILON/2,0,.999999],[.5,.5,.5,0]]){
 const values=rawValues.map(v=>Math.round(v*2**53)/2**53);let at=0;const fn=Function('Et',section('  function go(n, e, t)','  async function f1(n)')+'return go;')(()=>values[at++]);
 for(const axis of [[0,1,0],[0,0,0],[1,2,-3]]){at=0;const result=fn(new T.Vector3(...axis),.75,new T.Vector3()).toArray();scatter.push({tape_u53:values.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),axis,expected:result,calls:at});}
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/splash-random-reference.json'),JSON.stringify({tape,tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,scatter,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods).digest('hex')}));console.log(JSON.stringify({cases:cases.length,calls}));
