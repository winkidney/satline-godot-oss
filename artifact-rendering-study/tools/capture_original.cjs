async (page) => {
  const captures=[];
  const dir='artifact-rendering-study/output/playwright';
  await page.goto("http://127.0.0.1:8793/research/index.html?q=high&shot=1&noaudio=1&step=1&dt=0.016666667");
  await page.waitForFunction(()=>window.__ready && window.__step === 0);
  await page.addStyleTag({content:'#ui,#boot{display:none!important}'});
  const baseline=await page.evaluate(()=>{study.reset();study.frame(4);return study.info()});
  const variants=[
    ['harbor-baseline',{}],['harbor-no-ao',{quality:{ao:false}}],
    ['harbor-no-volume',{quality:{volSteps:0}}],['harbor-no-planar',{planar:false}],
    ['harbor-no-bloom',{quality:{bloom:false}}],
    ['harbor-no-lens',{tune:{flare:0,dirt:0,streak:0,ca:0,vignette:0,sharpen:0}}],
    ['harbor-aces-only',{tune:{agxMix:0}}],['harbor-agx-only',{tune:{agxMix:1}}],
    ['harbor-no-sun',{sun:0}],['harbor-no-ibl',{ibl:0}],
  ];
  for(const [name,settings] of variants){
    const metadata=await page.evaluate((settings)=>{
      study.reset();const g=__G;
      Object.assign(g.quality,settings.quality||{});Object.assign(g.render.tune,settings.tune||{});
      g.ground.setReflections(settings.planar!==false);
      const sun=g.render.sun.intensity,env=g.scene.environmentIntensity;
      if(settings.sun!==undefined)g.render.sun.intensity=settings.sun;
      if(settings.ibl!==undefined)g.scene.environmentIntensity=settings.ibl;
      study.frame(4);const result=study.info();
      g.render.sun.intensity=sun;g.scene.environmentIntensity=env;
      return result;
    },settings);
    const file=`${dir}/${name}.png`;await page.screenshot({path:file});captures.push({name,file,settings,metadata});
  }
  await page.evaluate(()=>{study.reset();__G.ground.setReflections(true);study.frame(8);study.timer(true);study.frame(4);});
  await page.waitForFunction(()=>study.gpu()?.pending===0,{},{timeout:15000});
  const gpu=await page.evaluate(()=>{const v=study.gpu();study.timer(false);return v;});
  const buffers=await page.evaluate(()=>study.buffers());
  const exports=[];
  for(const [target,options] of [
    ['scene',{mode:'hdr'}],['depthHalf',{channel:0,scale:0.02}],['aoA',{channel:0}],
    ['volA',{mode:'hdr'}],['volA',{channel:3}],['down.2',{mode:'hdr'}],
    ['streakB',{mode:'hdr'}],['dirt',{}]
  ]){
    const image=await page.evaluate(({target,options})=>{const [k,i]=target.split('.');let rt=__G.researchPost.rt[k];if(i!==undefined)rt=rt[+i];return study.texture(rt,options);},{target,options});
    exports.push({name:`buffer-${target.replace('.','-')}${options.channel===3?'-transmittance':''}.png`,...image});
  }
  const planar=await page.evaluate(()=>study.texture(__G.ground.reflectionTarget,{mode:'hdr'}));
  exports.push({name:'buffer-planar-reflection.png',...planar});
  return {baseline,captures,gpu,buffers,exports,note:'Frozen scene, dt=1/60, fixed manual exposure 0.7, grain disabled. GPU queries cover post passes only; step-mode fps is not performance.'};
}
