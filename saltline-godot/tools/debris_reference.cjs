async(page)=>await page.evaluate(async()=>{
 const T=__G.THREE;const source=await(await fetch('/source/extracted/bundle-1.js')).text();
 const start=source.indexOf('var jg = class {',source.indexOf('var c1 = 4'));const end=source.indexOf('\n    Ov = {',start);
 const L0=T.MeshStandardMaterial,Wo=T.InstancedMesh,Xs=T.InstancedBufferAttribute,Ao=T.DynamicDrawUsage;
 const XP=()=>__G.scene.getObjectByName('fx_debris').geometry;
 const Ds=new T.Matrix4(),Zw=new T.Vector3(),Zo=new T.Quaternion(),$g=new T.Vector3(),Zg=new T.Vector3();
 const Class=eval('('+source.slice(start,end).trim().replace(/^var jg = /,'').replace(/,$/,'')+')');
 const originalRandom=Math.random;Math.random=()=>.63;
 const pool=new Class(__G,4);const cases=[
  {position:[0,1,0],velocity:[1,2,-.5],size:[.02,.06,.03],color:[.6,.2,.1],life:3.73,floor:0},
  {position:[1,.03,1],velocity:[.4,-.3,.2],size:[.04,.03,.02],color:[.1,.5,.7],life:2.43,floor:0}
 ];
 for(const c of cases){pool.add(...c.position,...c.velocity,...c.size,...c.color,c.life,c.floor);const id=pool.next-1;c.axis=[pool.ax[id],pool.ay[id],pool.az[id]];c.angle=pool.ang[id];c.spin=pool.spin[id]}
 const frames=[];
 for(let i=0;i<260;i++){
  pool.update(1/60);frames.push({live:pool.live,state:Array.from(pool.state).slice(0,2),matrix:Array.from(pool.mesh.instanceMatrix.array).slice(0,32)});
 }
 Math.random=originalRandom;pool.mesh.material.dispose();
 const result={source:'Active original jg class with Three Matrix4/Quaternion composition',cases,frames};
 const response=await fetch('http://127.0.0.1:8794/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path:'fixtures/debris-reference.json',json:result})});
 if(!response.ok)throw Error(await response.text());return {cases:cases.length,frames:frames.length,errors:__errors};
})
