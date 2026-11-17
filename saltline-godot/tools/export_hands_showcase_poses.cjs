const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const source=path.resolve(root,'../artifact-rendering-study/source/extracted/bundle-1.js');
const text=fs.readFileSync(source,'utf8');
const engineEnd=text.indexOf('  var Kn = {');
const T=eval(text.slice(0,engineEnd)+'return ut;})()');
const start=text.indexOf('  var Us = K,'),end=text.indexOf('  var zy = {};',start);
if(start<0||end<start)throw Error('Fh fit literal boundary missing');
const literal=text.slice(start,end);
const result=vm.runInNewContext(literal+';JE();({poses:Object.fromEntries(Object.entries(di).map(([k,v])=>[k,Array.from(v)])),grips:Object.fromEntries(Object.entries(nn).map(([k,v])=>[k,{p:v.frame.p.toArray(),q:v.frame.q.toArray()}]))})',{K:T.Vector3,St:T.Quaternion,Je:T.Matrix4},{timeout:60000});
if(Object.keys(result.poses).length!==15||Object.values(result.poses).some(p=>p.length!==20))throw Error('Unexpected final di presets');
const output=path.join(root,'assets/export/hands-showcase-poses.json');
fs.writeFileSync(output,JSON.stringify(result.poses,null,2)+'\n');
fs.writeFileSync(path.join(root,'assets/export/hands-showcase-sockets.json'),JSON.stringify(result.grips,null,2)+'\n');
fs.writeFileSync(output.replace('.json','.provenance.json'),JSON.stringify({source:'artifact-rendering-study/source/extracted/bundle-1.js',sha256:crypto.createHash('sha256').update(text).digest('hex'),literal_sha256:crypto.createHash('sha256').update(literal).digest('hex'),table:'JE(Ey()) final di and nn.frame',consumer:'TD',note:'Original bundled Three math and literal fitting code on CPU; no Godot values used'},null,2)+'\n');
console.log('Exported 15 final fitted di presets and '+Object.keys(result.grips).length+' sockets');

// Original M5 evaluates independently from the Godot consumer.
const mstart=text.indexOf('  function M5('),mend=text.indexOf('  var vD =',mstart);
const M5=Function('nn','_y','D1', 'const $E=new _y(),xD=new D1();'+text.slice(mstart,mend)+';return M5;')(Object.fromEntries(Object.entries(result.grips).map(([k,f])=>[k,{frame:{p:new T.Vector3().fromArray(f.p),q:new T.Quaternion().fromArray(f.q)}}])),T.Quaternion,T.Vector3);
const cases=[];
for(const held of ['rifle','pistol'])for(const side of ['r','l']){
 const pistol=held==='pistol',left=side==='l';
 const p=new T.Vector3().fromArray(pistol?[.135,-.078,-.5]:[.118,-.122,-.275]);
 const q=new T.Quaternion().setFromEuler(new T.Euler(...(pistol?[.06,.12,-.07]:[.034,.085,-.03]),'YXZ'));
 const anchor=new T.Vector3().fromArray(pistol?[0,-.012,.045]:left?[0,-.04,-.256]:[0,-.055,.085]).applyQuaternion(q).add(p);
 const name=left?(pistol?'pistol_support':'foregrip'):(pistol?'pistol_grip':'rifle_grip');
 const input={p:anchor.toArray(),q:q.toArray()};
 if(left){anchor.x=-anchor.x;q.y=-q.y;q.z=-q.z;}
 const outP=new T.Vector3(),outQ=new T.Quaternion();M5(name,anchor,q,outP,outQ);
 if(left){outP.x=-outP.x;outQ.y=-outQ.y;outQ.z=-outQ.z;}
 cases.push({held,side,name,input,expected:{p:outP.toArray(),q:outQ.toArray()}});
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/hands-studio-sockets.json'),JSON.stringify({source:'Literal M5 plus original Fh.socket left reflection; TD default gun inputs',cases},null,2)+'\n');
