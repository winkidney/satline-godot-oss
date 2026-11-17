const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const {query}=require('./ground_query_reference.cjs');
function callback(event){const at=s.indexOf('(j) => {',s.indexOf('n.events.on("'+event+'",'));let end=s.indexOf('{',at)+1,depth=1;while(depth){if(s[end]==='{')depth++;if(s[end]==='}')depth--;end++;}return s.slice(at,end);}
const step=callback('player:step'),land=callback('player:land');
const methods=section('  function go(n, e, t)','  async function f1(n)')+section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function _(')+section('    function S(j, O, q, ue, de, $, se, fe, me)','    function R(')+section('    function k(j, O = 1)','    let C = { p: new K() };');

const tape=Array.from({length:32768},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const ground=JSON.parse(fs.readFileSync(path.join(root,'assets/export/fixtures/ground-query-reference.json'))),wet=ground.rows.find(r=>r.puddle&&r.x>-35&&r.x<25&&r.z>-30&&r.z<30),dry=ground.rows.find(r=>!r.puddle&&r.x>-35&&r.x<25&&r.z>-30&&r.z<30),wp=[wet.x,0,wet.z],dp=[dry.x,0,dry.z];
const operations=[
 {kind:'step',player:wp,payload:{pos:wp,surface:'concrete',sprint:false}},
 {kind:'step',player:wp,payload:{pos:wp,surface:'water',sprint:true}},
 {kind:'step',player:dp,payload:{pos:dp,surface:'concrete'}},
 {kind:'step',player:dp,payload:{pos:dp,surface:'water'}},
 {kind:'land',player:wp,payload:{surface:'concrete',speed:6}},
 {kind:'land',player:dp,payload:{surface:'concrete',speed:5}},
 {kind:'clear'},
 {kind:'land',player:dp,payload:{surface:'concrete',speed:5.0001}},
 {kind:'land',player:dp,payload:{surface:'concrete',speed:12,pos:wp}},
 {kind:'step',player:wp,payload:{pos:dp,surface:'concrete'}},
 {kind:'step',player:wp,payload:{surface:'concrete'}},
 {kind:'clear'},
 {kind:'land',player:[wet.x,-1,wet.z],payload:{surface:'water',speed:4}},
 {kind:'step',player:[wet.x,2,wet.z],payload:{surface:'wood'}},
 {kind:'clear'}];
const cases=[];for(const capacity of [2,256]){
 const c=new Pool(capacity,false),l=new Pool(capacity,true),n={player:{pos:new T.Vector3()}},fn=Function('Et','lt','l','c','Ri','st','jo','g','ee','n','fh','Hv','dh',methods+'return {step:('+step+'),land:('+land+')};')(M.random,(a,b)=>a+(b-a)*M.random(),l,c,new T.Vector3(0,1,0),new T.Vector3(),new T.Vector3(),()=>1,(x,z)=>query.isPuddle(x,z),n,6,4,2),rows=[];
 for(const op of operations){if(op.kind==='clear'){l.clear();c.clear();}else{n.player.pos.set(...op.player);const payload={...op.payload};if(payload.pos)payload.pos=new T.Vector3(...payload.pos);fn[op.kind](payload);}rows.push({op,expected:{calls,pools:{add:snapshot(c),lit:snapshot(l)}}});}
 cases.push({capacity,rows});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/ground-motion-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods+step+land).digest('hex')}));console.log(JSON.stringify({cases:cases.length,steps:operations.length,calls,wet:wp,dry:dp}));
