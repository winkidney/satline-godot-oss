const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{T}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const begin=s.indexOf('u1 = class {',s.indexOf('var c1 = 4')),end=s.indexOf('\n    Yg = class {',begin),particle=s.slice(begin,end).trim().replace(/^u1 = /,'').replace(/,$/,'');
function section(a,b){return s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));}
const methods=section('  function go(n, e, t)','  async function f1(n)')+section('    function M(j, O, q, ue, de, $, se, fe, me, ge, ce, P, D, B, X, re, Y, he)','    function z(')+section('    function Q(j, O = 1)','    let W = [];');

const addBegin=s.indexOf('      add(e, t, i, s, o, r, a, l, c, u, f, h, p, d) {',s.indexOf('jg = class')),addEnd=s.indexOf('      update(e) {',addBegin),addMethod=s.slice(addBegin,addEnd).trim();

const tape=Array.from({length:262144},(_,i)=>Math.round((((i*79+17)%8191)/8191)*2**53)/2**53);let calls=0;const M=Object.create(Math);M.random=()=>{if(calls>=tape.length)throw Error('exhausted');return tape[calls++]};
const Pool=Function('Math','const hh=1,dh=2,GP=4;return ('+particle+');')(M);
const fields=['px','py','pz','vx','vy','vz','life','s0','s1','seed','rot','rotv','frame','mode','flags','ramp','r','g','b','a','shade','drag','grav','wind','turb','fin','fout','sk','stretch','gy'];
function snapshot(p){return Array.from(p.order.slice(0,p.n),id=>Object.fromEntries(fields.map(k=>[k,p[k][id]])));}
const cases=[];
for(const capacity of [2,256])for(const size of [.1,.4,1,1.9,4,6])for(const grounded of [false,true])for(const shade of [1,.2]){
 const c=new Pool(capacity,false),l=new Pool(capacity,true),f={cap:256,next:0,mesh:{instanceColor:{array:new Float32Array(768)}}};
 for(const name of ['px','py','pz','vx','vy','vz','ax','ay','az','ang','spin','sx','sy','sz','age','life','floor','state'])f[name]=new Float32Array(256);
 f.add=Function('Math','return ({'+addMethod+'}).add;')(M);
 const lights=[],emitters=[],decals=[],events=[];const floor=grounded?0:-50;
 const factory=Function('Math','Et','lt','c','l','f','st','Ri','Ls','jo','Z','n','g','E','b','p','G','Bv','Gl','mo','Gg','Hv','hh',methods+'return Q;');
 const api=factory(M,M.random,(a,b)=>a+(b-a)*M.random(),c,l,f,new T.Vector3(),new T.Vector3(0,1,0),new T.Vector3(),new T.Vector3(),{pos:new T.Vector3(),size:0},{events:{emit:(name,event)=>events.push({name,position:event.pos.toArray(),size:event.size,calls,debris_count:f.next,add:c.n,lit:l.n})}},()=>shade,()=>floor,(pos,...args)=>lights.push({position:pos.toArray(),args}),{add:(...args)=>{M.random();M.random();M.random();decals.push({point:args[0].toArray(),normal:args[1].toArray(),args:args.slice(2)});}},(...args)=>emitters.push(args),1,2,0,5,4,1);
 api(new T.Vector3(3,1,2),size);
 const row={calls,pools:{add:snapshot(c),lit:snapshot(l)},debris:Array.from({length:f.next},(_,i)=>({...Object.fromEntries(['px','py','pz','vx','vy','vz','ax','ay','az','ang','spin','sx','sy','sz','age','life','floor','state'].map(k=>[k,f[k][i]])),r:f.mesh.instanceColor.array[i*3],g:f.mesh.instanceColor.array[i*3+1],b:f.mesh.instanceColor.array[i*3+2]})),lights,emitters,decals,events};
 cases.push({capacity,size,grounded,shade,row});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/explosion-random-reference.json'),JSON.stringify({tape_u53:tape.map(v=>BigInt(Math.round(v*9007199254740992)).toString(16)),cases,source_sha256:crypto.createHash('sha256').update(s).digest('hex'),methods_sha256:crypto.createHash('sha256').update(particle+methods+addMethod).digest('hex')}));console.log(JSON.stringify({cases:cases.length,calls}));
