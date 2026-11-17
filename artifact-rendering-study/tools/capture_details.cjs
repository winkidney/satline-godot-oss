async(page)=>{
 const dir='artifact-rendering-study/output/playwright';const captures=[],exports=[];
 const base='http://127.0.0.1:8793/research/index.html?q=high&noaudio=1&step=1&dt=0.016666667';
 for(const [name,query,settings] of [
   ['render-pcss','&shot=1&show=render',{}],['render-stock-pcf','&shot=1&show=render&soft=0',{}],
   ['render-no-volume','&shot=1&show=render',{volSteps:0}],['render-no-ao','&shot=1&show=render',{ao:false}],
 ]){
   await page.goto(base+query);await page.waitForFunction(()=>window.__ready && window.__step === 0);
   await page.addStyleTag({content:'#ui,#boot{display:none!important}'});
   const metadata=await page.evaluate(settings=>{study.reset();Object.assign(__G.quality,settings);study.frame(4);return study.info()},settings);
   const file=`${dir}/${name}.png`;await page.screenshot({path:file});captures.push({name,file,metadata});
 }
 await page.goto(base+'&autostart=1&dynres=0');await page.waitForFunction(()=>window.__ready && window.__step === 0);
 await page.addStyleTag({content:'#ui,#boot{display:none!important}'});
 const adaptation=await page.evaluate(()=>{
   study.reset();const g=__G;g.quality.motionBlur=false;
   const box=g.level.interiorBoxes[0];
   function read(frame){return {frame,simulation_seconds:frame/60,...g.researchPost.readAdapt()};}
   study.view([-32,1.68,6],[60,24,40],62);g.render.autoExposure=true;study.frame(120);
   const bright=read(0);
   const x=(box.min.x+box.max.x)/2,z=(box.min.z+box.max.z)/2;
   study.view([x,1.68,z],[x-6,1.68,z],62);
   const samples=[read(0)];let previous=0;
   for(const f of [1,4,16,64,180]){study.frame(f-previous);samples.push(read(f));previous=f;}
   return {bright,samples,box,camera:study.info().camera,autoExposure:g.render.autoExposure,dt:1/60,note:'No shot/show flags: ordinary exponential adaptation, not snapshot fast adaptation. Frozen scene; only render frames advanced.'};
 });
 const file=`${dir}/adaptation-dark-interior.png`;await page.screenshot({path:file});captures.push({name:'adaptation-dark-interior',file,metadata:await page.evaluate(()=>study.info())});
 // Advance the real showcase update loop for deterministic temporal VFX frames.
 await page.goto(base+'&shot=1&show=fx');await page.waitForFunction(()=>window.__ready && window.__step === 0);
 await page.addStyleTag({content:'#ui,#boot{display:none!important}'});
 await page.evaluate(()=>{study.reset();__G.quality.motionBlur=false;});
 for(let i=0;i<12;i++){
   await page.evaluate(()=>window.__step=8);await page.waitForFunction(()=>window.__step===0);
   const file=`${dir}/fx-motion-${String(i).padStart(2,'0')}.png`;await page.screenshot({path:file});captures.push({name:`fx-motion-${i}`,file,metadata:await page.evaluate(()=>study.info())});
 }
 return {captures,exports,adaptation};
}
