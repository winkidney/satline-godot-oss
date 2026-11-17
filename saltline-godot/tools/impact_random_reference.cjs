const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('  function go(n, e, t)','  async function f1(n)')+section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function z(')+section('    function L(j, O, q = 1, ue = 0.5, de = 0.48, $ = 0.45)','    function U(')+section('    function k(j, O = 1)','    let C = { p: new K() };')+section('    function A(j, O, q, ue, de)','    function F(j, O, q = {})');
const addBegin=s.indexOf('      add(e, t, i, s, o, r, a, l, c, u, f, h, p, d) {',s.indexOf('jg = class')),addEnd=s.indexOf('      update(e) {',addBegin),addMethod=s.slice(addBegin,addEnd).trim();

const tape=Array.from({length:262144},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const cases=[];
for(const capacity of [2,80])for(const surface of ['metal','enemy','wood','dirt','rubber','glass','concrete','water'])for(const far of [false,true])for(const shade of [1,.2]){
 const c=new Pool(capacity,false),l=new Pool(capacity,true),f={cap:256,next:0,mesh:{instanceColor:{array:new Float32Array(768)}}};
 for(const name of ['px','py','pz','vx','vy','vz','ax','ay','az','ang','spin','sx','sy','sz','age','life','floor','state'])f[name]=new Float32Array(256);
 f.add=Function('Math','return ({'+addMethod+'}).add;')(M);
 const lights=[],decals=[];let m=0,x=-1;
 const factory=Function('Math','Et','lt','c','l','f','st','jt','Ut','Qg','Ri','Ls','C','n','g','E','b','p','Bv','Gl','mo','fh','Hv','dh','hh','let m=0,x=-1;'+methods+'return {impact:A,setTime:(value)=>m=value};');
 const api=factory(M,M.random,(a,b)=>a+(b-a)*M.random(),c,l,f,new T.Vector3(),new T.Vector3(),new T.Vector3(),new T.Vector3(),new T.Vector3(0,1,0),new T.Vector3(),{p:new T.Vector3()},{camera:{position:new T.Vector3(far?100:0,0,0)}},()=>shade,()=>-50,(pos,...args)=>lights.push({position:pos.toArray(),args}),{add:(pos,normal,...args)=>decals.push(args)},1,2,0,6,4,2,1);
 const rows=[];for(const [step,time] of [0,.05,.09,.090001,.18,.180002].entries()){const normal=step===4?[0,0,0]:step===5?[.0001,0,0]:[0,1,0],direction=step===2?[0,0,0]:step===3?[.0001,0,0]:[0,-1,0],eventSurface=surface==='metal'&&step%2===1?'enemy':surface;api.setTime(time);api.impact(new T.Vector3(3,1,2),new T.Vector3(...normal),eventSurface,new T.Vector3(...direction),null);rows.push({time,normal,direction,surface:eventSurface,calls,pools:{add:snapshot(c),lit:snapshot(l)},debris:Array.from({length:f.next},(_,i)=>({...Object.fromEntries(['px','py','pz','vx','vy','vz','ax','ay','az','ang','spin','sx','sy','sz','age','life','floor','state'].map(k=>[k,f[k][i]])),r:f.mesh.instanceColor.array[i*3],g:f.mesh.instanceColor.array[i*3+1],b:f.mesh.instanceColor.array[i*3+2]})),lights:structuredClone(lights)});}
 cases.push({capacity,surface,far,shade,rows});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/impact-random-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods+addMethod).digest('hex')}));console.log(JSON.stringify({cases:cases.length,calls}));
