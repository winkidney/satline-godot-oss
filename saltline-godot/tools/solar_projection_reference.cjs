const fs=require('fs');
const source=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');const T=eval(source.slice(0,source.indexOf('  var Kn = {'))+'return ut;})()');
const start=source.indexOf('      te\n        .copy(Z0.dir)');
if(start<0)throw Error('source solar block missing');const code=source.slice(start,source.indexOf('\n      {',start));
const run=new Function('Z0','ge','te','oe',code+'\nreturn {uv:[Ze,qe],on:je,front:Ne,edge:ke};');const cases=[];
for(let i=0;i<640;i++){
 const size=[[1280,720],[800,600],[640,900],[1920,1080]][i%4];const camera=new T.PerspectiveCamera(40+i%70,size[0]/size[1],.08,900);camera.position.set(Math.sin(i*.31)*45,Math.cos(i*.2)*6+2,Math.sin(i*.17)*30);camera.rotation.set(Math.sin(i*.13)*1.3,Math.sin(i*.19)*Math.PI,Math.sin(i*.23)*.25,'YXZ');camera.updateMatrixWorld();
 const direction=new T.Vector3(.9163473614874841,.22508532350948027,.33112552036283543);const result=run({dir:direction},camera,new T.Vector3(),new T.Vector3());cases.push({size,view:camera.matrixWorld.elements,fov:camera.fov,direction:direction.toArray(),result});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/solar-projection-reference.json',JSON.stringify({three:T.REVISION,cases,scope:'Actual original solar projection block with original Three r180 camera transforms and varying FOV/roll/aspect.'}));console.log({cases:cases.length,three:T.REVISION});
