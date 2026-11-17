const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {T,data,source_sha256}=require('./weapon_magazine_reference.cjs');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
function cut(a,b,start=0){const x=source.indexOf(a,start),y=source.indexOf(b,x);if(x<0||y<0)throw Error(a);return source.slice(x,y);}
const config={rifle:Function('return '+cut('    sc = {',';\n  function ID').trim().slice(5))(),pistol:Function('return '+cut('    ol = {',';\n  function FD').trim().slice(5))()};
fs.writeFileSync(path.join(root,'assets/export/weapon-arm-config.json'),JSON.stringify(config,null,2));
const tn=cut('  function tn(','  function ly('),methods={},cases=[];
for(const gun of ['rifle','pistol']){
 const offset=source.indexOf(gun==='rifle'?'  function wS(n)':'  function zS(n)');
 const method=cut('      armTargets(','      setLocked(',offset).trim().replace(/,$/,'');methods[gun]=method;
 const h=JSON.parse(JSON.stringify(data.modules.weapon.rigs[gun].holds));
 for(const v of Object.values(h))if(v?.p&&v?.q){v.p=new T.Vector3().fromArray(v.p);v.q=new T.Quaternion().fromArray(v.q);v.pose=Float32Array.from(v.pose);}
 const makeTarget=()=>({p:new T.Vector3(),q:new T.Quaternion(),pose:new Float32Array(20),pole:new T.Vector3(),sh:new T.Vector3()});
 const state={spV:{x:0},adsV:{x:0},reload:null,hol:0};
 const left={p:h[gun==='rifle'?'fore':'support'].p.clone(),q:h[gun==='rifle'?'fore':'support'].q.clone(),pose:new Float32Array(20),busy:false};
 const api=Function('THREE','h','state','left','config',`const Un=20,Ot=x=>{x=Math.min(1,Math.max(0,x));return x*x*x*(x*(6*x-15)+10)};${tn};const m=h,y=h,s=state,i=state,OLEFT=left,G=left,sc=config,ol=config,te=new THREE.Vector3(),Z=te;let fe=1,O=1,me=0,q=0,ue=0;${gun==='rifle'?'const O=OLEFT;':''}return {set(f,w){me=f;q=f;ue=w;},${method}};`.replace(gun==='rifle'?'let fe=1,O=1,me=0,q=0,ue=0;':'__NO_MATCH__',gun==='rifle'?'let fe=1,me=0,q=0,ue=0;':'__NO_MATCH__'))(T,h,state,left,config[gun]);
 const rows=[];
 for(let j=0;j<360;j++){
  state.spV.x=j%80/60-.1;state.adsV.x=(j%90)/70;state.reload=j%37<7?{}:null;state.hol=j%53<9?.2:0;
  left.busy=j%13<5;left.pose.fill((j%10)*.03);left.p.set(.02*Math.sin(j),-.1,.03);left.q.setFromEuler(new T.Euler(.1*Math.sin(j),.2,0));
  const input={dt:[0,1/60,1/120,.03][j%4],state:JSON.parse(JSON.stringify(state)),finger:(j%20)/19,stop_weight:(j%12)/11,left:{p:left.p.toArray(),q:left.q.toArray(),pose:Array.from(left.pose),busy:left.busy},snap:j>0&&j%61===0};
  api.set(input.finger,input.stop_weight);if(input.snap)api.snapArms();const targets={r:makeTarget(),l:makeTarget()};api.armTargets(targets,input.dt);
  const output={};for(const [k,v] of Object.entries(targets))output[k]={p:v.p.toArray(),q:v.q.toArray(),pose:Array.from(v.pose),pole:v.pole.toArray(),sh:v.sh.toArray(),trig:v.trig};rows.push({input,expected:output});
 }
 cases.push({gun,rows});
}
const report={source_sha256,methods_sha256:crypto.createHash('sha256').update(JSON.stringify(methods)+JSON.stringify(config)).digest('hex'),cases};
fs.writeFileSync(path.join(root,'assets/export/fixtures/weapon-arm-targets-reference.json'),JSON.stringify(report));console.log(JSON.stringify({cases:cases.length,steps:cases.reduce((n,c)=>n+c.rows.length,0),methods_sha256:report.methods_sha256}));
