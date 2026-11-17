const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');const {T,source_sha256}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),s=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const cut=(a,b)=>s.slice(s.indexOf(a),s.indexOf(b,s.indexOf(a)));
const table='var '+cut('    t0 = [','  function d0('),poses=cut('  function d0(','  var IE = '),finger=cut('  var IE = ','  function tr('),constants=cut('  var U0 = K,','  function Lh('),globals=cut('  var F1 = ','  function Fh('),fh=cut('  function Fh(','  async function TD(');
const make=Function('T','left',`const K=T.Vector3,St=T.Quaternion,Je=T.Matrix4,_0=T.Euler,Us=K,ja=St,Cu={upper:.3,fore:.27},At=T.Group,qr=T.Bone,Un=20,Eh=['thumb','index','middle','ring','little'];${table};${poses};${finger};${constants};${globals};const _a=class{constructor(bones){this.bones=bones}dispose(){}},Gr=class extends T.Object3D{constructor(g){super();this.geometry=g}bind(){}},aS=()=>({userData:{triCount:0}}),lS=()=>({});${fh};return {arm:Fh({}, {side:left?'left':'right'}),config:{bone_names:T1,digits:t0.map(d=>({...d,q0:d.q0?.toArray(),qRoll:d.qRoll?.toArray()})),rest:Array.from(jl),min:Array.from(xs.min),max:Array.from(xs.max)}};`);
const cases=[];let config;
for(const left of [false,true]){const made=make(T,left),arm=made.arm;config=made.config;const rows=[];
 for(let j=0;j<420;j++){
  const pose=Array.from({length:20},(_,k)=>Math.fround(.4+1.8*Math.sin(j*.07+k*.3)));
  const input={pose,trigger:(j%35)/25-.2,impulse:j%47===0?.35+(j%3)*.4:0,dt:[0,1/60,1/120,.031,.08][j%5],shoulder:[left?-.2:.2,-.23,.15],hand:[.1*Math.sin(j*.07),-.13+.03*Math.cos(j*.11),-.2],rotation:new T.Quaternion().setFromEuler(new T.Euler(.3*Math.sin(j*.03),.4,.2)).toArray(),pole:[left?-.8:.8,-.6,0]};
  arm.setFingers(input.pose);arm.setTrigger(input.trigger);if(input.impulse)arm.impulse(input.impulse);arm.solve(input.shoulder,input.hand,new T.Quaternion().fromArray(input.rotation),input.pole,{lean:.2});arm.update(input.dt);
  rows.push({input,expected:{pose:Array.from(arm.pose),shown:Array.from(arm.shown),trigger:arm.trigger,bones:arm.bones.map(b=>({p:b.position.toArray(),q:b.quaternion.toArray()}))}});
 }
 cases.push({left,rows});
}
fs.writeFileSync(path.join(root,'assets/export/weapon-arm-pose-config.json'),JSON.stringify(config,null,2));
const result={source_sha256,fh_sha256:crypto.createHash('sha256').update(fh+table+poses+finger+constants+globals).digest('hex'),cases};fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-arm-pose-reference.json'),JSON.stringify(result));console.log(JSON.stringify({steps:840,fh_sha256:result.fh_sha256}));
