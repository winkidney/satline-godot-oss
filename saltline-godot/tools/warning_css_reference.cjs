async(page)=>{
 await page.setViewportSize({width:1280,height:720});
 return await page.evaluate(async()=>{
  const warning=document.createElement('div');warning.className='h-warn on';warning.textContent='Machines inbound';document.querySelector('#app').appendChild(warning);
  await new Promise(requestAnimationFrame);
  const animation=warning.getAnimations().find(a=>a.animationName==='warn');if(!animation)throw Error('warn animation missing');animation.pause();
  const rows=[];
  for(const seconds of [0,.05,.1,.272,.3,.476,.6,.68,1,2.788,3,3.399,3.4,4]){
   animation.currentTime=seconds*1000;const style=getComputedStyle(warning);rows.push({seconds,alpha:Number(style.opacity),spacing:Number.parseFloat(style.letterSpacing),pixels:Number.parseFloat(style.fontSize)});
  }
  return {rows,scope:'Original unchanged stylesheet warn keyframes sampled through browser Animation.currentTime; no font pixel comparison'};
 });
}
