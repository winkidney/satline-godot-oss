async(page)=>{
 await page.goto('http://127.0.0.1:8793/research/index.html?q=high&shot=1&noaudio=1&step=1&dt=0.016666667');
 await page.waitForFunction(()=>window.__ready&&window.__step===0);
 const exports=await page.evaluate(()=>{
   study.reset();study.frame(4);const r=__G.researchPost.rt;
   const out=['depthHalf','volA','adapt'].map(k=>({name:`numeric-${k}.bin`,...study.texture(k==='adapt'?r[k][0]:r[k],{binary:true})}));
   const a=__G.mats.researchSet('fabric',true),h=__G.mats.researchHeightTargets.get(a.size);
   out.push({name:'numeric-fabric-height-packed.bin',...study.texture(h,{attachment:2,binary:true})});
   out.push({name:'texture-fabric-height-packed.png',...study.texture(h,{attachment:2})});
   return out;
 });
 return {exports,note:'Typed GPU readback bytes, no tone mapping or 8bit preview quantization. See dtype/endian/channels per asset. Adapt entry is buffer index0, not necessarily newest ping-pong.'};
}
