const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {T,source_sha256}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const code=source.slice(source.indexOf('  function vS('),source.indexOf('  var Pn = K,',source.indexOf('  function vS(')));
const tn=source.slice(source.indexOf('  function tn('),source.indexOf('  function ly('));
const make=Function('T','relaxed=null',`const W0=T.Vector3,Ur=T.Quaternion,_0=T.Euler,Un=20,S5={right:[.8,-.6,0],left:[-.8,-.6,0]},xS={shoulder:{right:[.19,-.24,.1],left:[-.19,-.24,.1]},lean:.2},di={relaxed:relaxed?Float32Array.from(relaxed):new Float32Array(20)},cS=x=>{x=Math.min(1,Math.max(0,x));return x*x*x*(x*(6*x-15)+10)};const A5=n=>({p:new W0(),q:new Ur(),pose:new Float32Array(20),trig:0,pole:new W0().fromArray(S5[n]),sh:new W0().fromArray(xS.shoulder[n])});${tn};const calls={};function Fh(n,e){let pose,trig;return {side:e.side,group:new T.Object3D(),setLayer(){},setFingers(p){pose=Array.from(p)},setTrigger(t){trig=t},solve(sh,p,q,pole,h){calls[e.side]={p:p.toArray(),q:q.toArray(),sh:sh.toArray(),pole:pole.toArray(),pose,trig,lean:h.lean}},update(){}}};${code};return {api:vS({camera:new T.Object3D()}),calls};`);
const {api,calls}=make(T),rows=[];
for(let j=0;j<540;j++){
 let action=null;
 if([0,35,48,89,180,239,320,349,399,439].includes(j))action={kind:'blend',duration:j===180?0:.13+(j%3)*.05};
 if([90,210,440].includes(j))action={kind:'snap'};
 if([240,350,460].includes(j))action={kind:'attach',offset:j===350?null:{p:[.03,-.04,.1],q:new T.Quaternion().setFromEuler(new T.Euler(.1,.15,-.2,'YXZ')).toArray()}};
 if(action?.kind==='blend')api.blend(action.duration);
 if(action?.kind==='snap')api.snap();
 if(action?.kind==='attach'){
  const o=action.offset;
  api.attach(o?new T.Object3D():null,o?{p:o.p,r:[.1,.15,-.2]}:null);
 }
 const root={p:[.07*Math.sin(j*.07),-.2+.03*Math.cos(j*.05),-.3],q:new T.Quaternion().setFromEuler(new T.Euler(.3*Math.sin(j*.03),.25*Math.cos(j*.04),.2*Math.sin(j*.02),'YXZ')).toArray()};
 const targets={};for(const [side,sign] of [['r',1],['l',-1]])targets[side]={p:[sign*.08+.01*Math.sin(j*.1),-.1,-.03],q:new T.Quaternion().setFromEuler(new T.Euler(.2*Math.sin(j*.06),sign*.4,.1)).toArray(),pose:Array.from({length:20},(_,k)=>Math.fround(.3+.2*Math.sin(j*.1+k))),pole:[sign*.7,-.6,.01*Math.sin(j*.03)],sh:[sign*.2,-.23,.15],trig:(j%20)/19};
 const dt=[0,1/60,1/120,.031][j%4];
 api.update(dt,{armTargets(out){for(const side of ['r','l']){const t=targets[side],o=out[side];for(const k of ['p','pole','sh'])o[k].fromArray(t[k]);o.q.fromArray(t.q);o.pose.set(t.pose);o.trig=t.trig;}}},{position:new T.Vector3().fromArray(root.p),quaternion:new T.Quaternion().fromArray(root.q)});
 rows.push({input:{dt,action,root,targets},expected:JSON.parse(JSON.stringify({r:calls.right,l:calls.left}))});
}
const result={source_sha256,stage_sha256:crypto.createHash('sha256').update(code).digest('hex'),rows,scope:'Literal original vS normal update/blend/snap/attach, original Three math, mocked Fh receivers capture solver inputs. Synthetic gun-local targets/root; no Fh IK, production integration, death-drop or whole image proof.'};
if(require.main===module){fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-arm-blend-reference.json'),JSON.stringify(result));console.log(JSON.stringify({steps:rows.length,stage_sha256:result.stage_sha256}));}
module.exports={make,T,source_sha256,stage_sha256:result.stage_sha256};
