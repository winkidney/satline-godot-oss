const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8');
 const css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage({viewport:{width:1280,height:720}});
  await page.setContent(`<style>${css}</style><div class="h-cross"><i class="c-b"></i></div><div class="h-marks"><div class="h-wm"></div></div>`);
  const stages=await page.evaluate(async()=>{
   const cross=document.querySelector('.h-cross'),arm=document.querySelector('.c-b'),marks=document.querySelector('.h-marks'),marker=document.querySelector('.h-wm');
   const inputs=[
    {ads:0,spread:.012,marker:'normal',ms:60},
    {ads:0,spread:.06,marker:'normal',ms:20},
    {ads:0,spread:.012,marker:'dim',ms:10},
    {ads:.8,spread:.06,marker:'dim',ms:30},
    {ads:0,spread:.012,marker:'offscreen',ms:15},
    {ads:.8,spread:.03,sprinting:true,marker:'near',ms:20},
    {ads:0,spread:.03,sprinting:true,marker:'normal',ms:300},
    {ads:0,spread:.03,alive:false,marker:'normal',ms:100},
    {ads:0,spread:.03,state:'reloading_hidden',marker:'normal',ms:30},
    {ads:0,spread:.03,marker:'normal',ms:100}
   ];
   const targets=[[cross,'opacity'],[arm,'transform'],[marks,'opacity'],[marker,'opacity']];
   for(const [element,property]of targets)getComputedStyle(element)[property];
   await new Promise(requestAnimationFrame);let previous=new Set(),gap=0;const result=[];
   for(const input of inputs){
    const visible=input.ads<=.6&&input.alive!==false&&input.state!=='reloading_hidden';
    cross.classList.toggle('off',!visible);marks.classList.toggle('off',input.ads>=.5);
    marker.className='h-wm'+(input.marker==='normal'?'':' '+input.marker);
    if(visible){gap=Math.round(Math.max(4,Math.min(70,Math.tan(input.spread)/Math.tan(74*Math.PI/360)*360+4+(input.sprinting?10:0)))*2)/2;arm.style.transform=`translate3d(-50%,${gap}px,0)`;}
    for(const [element,property]of targets)getComputedStyle(element)[property];
    const animations=targets.map(([element,property])=>element.getAnimations().find(a=>a.transitionProperty===property));
    const offsets=animations.map(a=>a&&previous.has(a)?Number(a.currentTime):0);
    for(let i=0;i<animations.length;i++)if(animations[i]){animations[i].pause();animations[i].currentTime=offsets[i];}
    const samples=[];
    for(const ms of [0,input.ms*.5,input.ms]){
     for(let i=0;i<animations.length;i++)if(animations[i])animations[i].currentTime=offsets[i]+ms;
     samples.push({ms,cross_alpha:Number(getComputedStyle(cross).opacity),gap:new DOMMatrixReadOnly(getComputedStyle(arm).transform).m42,marks_alpha:Number(getComputedStyle(marks).opacity),marker_alpha:Number(getComputedStyle(marker).opacity)});
    }
    result.push({input,gap_target:gap,samples});previous=new Set(animations.filter(Boolean));
   }
   const initialMarkers={};
   for(const state of ['normal','dim','offscreen','near']){const fresh=document.createElement('div');fresh.className='h-wm';marks.appendChild(fresh);if(state!=='normal')fresh.classList.add(state);initialMarkers[state]={alpha:Number(getComputedStyle(fresh).opacity),animations:fresh.getAnimations().length};fresh.remove();}
   return {stages:result,initial_markers:initialMarkers};
  });
  const data={source_sha256:crypto.createHash('sha256').update(html).digest('hex'),css_sha256:crypto.createHash('sha256').update(css).digest('hex'),stages:stages.stages,initial_markers:stages.initial_markers,scope:'Actual original CSS in Chrome; cross .1s ease/gap .06s linear, marker parent .15s ease and child .25s ease, exact interrupted/reversed animation sampling. Fixed projection inputs; no complete HUD pixel proof.'};
  fs.writeFileSync(path.join(root,'assets/export/fixtures/navigation-transition-css.json'),JSON.stringify(data,null,2));console.log(JSON.stringify({stages:stages.stages.length,samples:stages.stages.reduce((n,s)=>n+s.samples.length,0)}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
