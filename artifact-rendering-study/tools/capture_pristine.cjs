async(page)=>{
 const url='http://127.0.0.1:8793/source/saltline.original.html?q=high&shot=1&noaudio=1&step=1&dt=0.016666667';
 await page.goto(url);await page.waitForFunction(()=>window.__ready&&window.__step===0);
 const metadata=await page.evaluate(()=>{const g=__G,gl=g.renderer.getContext(),ext=gl.getExtension('WEBGL_debug_renderer_info');return {url:location.href,ready:__ready,fatal:__fatal,errors:__errors,stats:__stats(),gpu:gl.getParameter(ext.UNMASKED_RENDERER_WEBGL),quality:{...g.quality},params:{...g.params},time:{...g.time},note:'Untouched original HTML; first 3 simulation frames. UI retained. fps is not used as a benchmark.'}});
 const file='artifact-rendering-study/output/playwright/pristine-original.png';await page.screenshot({path:file});
 return {captures:[{name:'pristine-original',file,metadata}]};
}
