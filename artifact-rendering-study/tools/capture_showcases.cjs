async (page) => {
  const base='http://127.0.0.1:8793/research/index.html?q=high&shot=1&noaudio=1&step=1&dt=0.016666667';
  const dir='artifact-rendering-study/output/playwright';const captures=[],exports=[];
  for(const scene of ['render','ground','mats','hands','weapon','fx','backdrop']){
    await page.goto(base+'&show='+scene+(scene==='mats'?'&only=glove_fabric,chainlink,paint_red,steel_galv,glass_dirty':''));
    await page.waitForFunction(()=>window.__ready && window.__step === 0);
    await page.addStyleTag({content:'#ui,#boot{display:none!important}'});
    const metadata=await page.evaluate(()=>{study.reset();study.frame(6);return study.info()});
    const file=`${dir}/showcase-${scene}.png`;await page.screenshot({path:file});captures.push({name:scene,file,metadata});
    if(scene==='hands'){
      await page.evaluate(()=>{study.view([0.45,0.1,0.65],[0,-0.15,-0.15],45);study.frame(4)});
      const file=`${dir}/showcase-hands-detail.png`;await page.screenshot({path:file});captures.push({name:'hands-detail',file,metadata:await page.evaluate(()=>study.info())});
    }
    if(scene==='mats'){
      for(const set of ['fabric','paint','chainlink','tarp']){
        const images=await page.evaluate((set)=>{
          const a=__G.mats.researchSet(set,true),F=__G.mats.researchHeightTargets.get(a.size);
          return [
            {kind:'albedo',...study.texture(a.targets[0])},
            {kind:'alpha',...study.texture(a.targets[0],{channel:3})},
            {kind:'orm',...study.texture(a.targets[1])},
            {kind:'normal',...study.texture(a.targets[2])},
            {kind:'height',...study.texture(F,{attachment:2,channel:'height'})},
          ];
        },set);
        for(const image of images)exports.push({name:`texture-${set}-${image.kind}.png`,...image});
      }
    }
  }
  return {captures,exports,note:'Authored showcase scenes, fixed dt step-mode; textures regenerated for height readback. Texture dump mode raw preserves encoded channel values, not final lit appearance.'};
}
