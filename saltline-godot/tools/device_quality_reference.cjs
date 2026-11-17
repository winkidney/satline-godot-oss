const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');const text=fs.readFileSync(path.resolve(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
const start=text.indexOf('  function UM('),end=text.indexOf('  function BM(',start),literal=text.slice(start,end),cases=[];
for(const descriptor of [
 ['Linux',0,1920,1080,'NVIDIA RTX 4070'],['Windows',0,1920,1080,'Intel UHD 620'],['Windows',0,1920,1080,'Intel Arc A770'],
 ['Linux',0,1920,1080,'llvmpipe'],['Linux',0,1920,1080,'SwiftShader'],['Linux',0,1920,1080,'Software'],['Linux',0,1920,1080,'Mali'],['Linux',0,1920,1080,'Adreno'],['Linux',0,1920,1080,'PowerVR'],['Linux',0,1920,1080,''],
 ['Android',0,1920,1080,'NVIDIA'],['iPhone',0,1920,1080,'NVIDIA'],['iPad',0,1920,1080,'NVIDIA'],['Mobile',0,1920,1080,'NVIDIA'],['Linux',2,899,1200,'NVIDIA'],['Linux',2,900,1200,'NVIDIA'],['Linux',1,400,600,'NVIDIA']]){
 for(const requested of ['', 'ultra']){
  const [ua,touch,width,height,renderer]=descriptor;
  const gl={getExtension:()=>null,getParameter:()=>renderer,RENDERER:1};
  const jr=Object.fromEntries(['test','low','medium','high','ultra'].map(name=>[name,{name}]));
  const expected=vm.runInNewContext(literal+';UM(requested).name',{requested,jr,navigator:{userAgent:ua,maxTouchPoints:touch},screen:{width,height},document:{createElement:()=>({getContext:()=>gl})}});
  cases.push({requested,user_agent:ua,touch_points:touch,screen:[width,height],renderer,expected});
 }
}
fs.writeFileSync(path.join(root,'assets/export/fixtures/device-quality.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(text).digest('hex'),method:'UM literal; browser environment stubs',cases},null,2)+'\n');console.log(cases.length+' original UM cases');
