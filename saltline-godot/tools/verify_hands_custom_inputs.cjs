const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const s=fs.readFileSync(path.resolve(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const T=eval(s.slice(0,s.indexOf('  var Kn = {'))+'return ut;})()');
let comparisons=0,maximum=0;
for(const label of ['custom-grip','custom-gun']){
 const report=JSON.parse(fs.readFileSync(path.join(root,'evidence/hands-studio-fp-'+label+'.json'),'utf8'));
 for(const side of ['r','l']){
  let anchor,q;
  if(label==='custom-grip'){
   const sign=side==='r'?1:-1;
   anchor=new T.Vector3(report.grip[0]+.11*sign,report.grip[1],report.grip[2]);
   q=new T.Quaternion().setFromRotationMatrix(new T.Matrix4().makeBasis(new T.Vector3(0,.86*sign,-.5*sign).normalize(),new T.Vector3(-sign,0,0),new T.Vector3(0,.5,.86).normalize()));
  }else{
   const p=report.custom_gun;q=new T.Quaternion().setFromEuler(new T.Euler(p[3]||0,p[4]||0,p[5]||0,'YXZ'));
   anchor=new T.Vector3(0,-.012,.045).applyQuaternion(q).add(new T.Vector3(...p.slice(0,3)));
  }
  const actual=report.grip_inputs[side];
  for(const [a,b] of [[actual.anchor,anchor.toArray()],[actual.quaternion,q.toArray()]])for(let j=0;j<a.length;j++){maximum=Math.max(maximum,Math.abs(a[j]-b[j]));comparisons++;}
 }
}
const result={comparisons,maximum,passed:maximum<1e-6,scope:'Actual Main runner report part anchors and basis quaternions against original bundled Three TD equations; not full IK or pixels'};
fs.writeFileSync(path.join(root,'evidence/hands-custom-input-verification.json'),JSON.stringify(result,null,2)+'\n');console.log(result);if(!result.passed)process.exitCode=1;
