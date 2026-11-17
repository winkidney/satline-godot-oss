const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8'),css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),profiles=[];
  for(const reduced of [false,true]){
   await page.emulateMedia({reducedMotion:reduced?'reduce':'no-preference'});
   await page.setContent(`<style>${css}</style><div id="app"><div class="menu"><div class="m-veil"></div><div class="m-bars"><i></i></div><button class="btn">Button</button><button class="toggle"><i></i></button></div><div class="hud"><div class="h-cross"></div><div class="h-health"></div><div class="h-fl"></div><div class="h-warn on">Wave</div><div class="h-cue urgent on">Reload</div></div><div class="comms"></div><div class="loc-card on"><b>Location</b></div><div id="boot"><div class="boot-bar"><i></i></div></div><div class="t-stick"></div></div>`);
   profiles.push(await page.evaluate(async reduced=>{
    const selectors={hud:'.hud',veil:'.m-veil',bars:'.m-bars i',button:'.btn',cross:'.h-cross',health:'.h-health',feed:'.h-fl',radio:'.comms',location:'.loc-card',boot:'#boot',boot_progress:'.boot-bar i',stick:'.t-stick'};
    const transitions=Object.fromEntries(Object.entries(selectors).map(([key,selector])=>[key,getComputedStyle(document.querySelector(selector)).transitionDuration.split(',').map(parseFloat)]));
    transitions.toggle=getComputedStyle(document.querySelector('.toggle i'),'::after').transitionDuration.split(',').map(parseFloat);
    const warning=document.querySelector('.h-warn'),cue=document.querySelector('.h-cue'),samples=[];
    for(const seconds of [.1,.4,1,3.3]){
     for(const n of [warning,cue])for(const a of n.getAnimations()){a.pause();a.currentTime=seconds*1000;}
     await new Promise(requestAnimationFrame);
     samples.push({seconds,warning_alpha:parseFloat(getComputedStyle(warning).opacity),warning_spacing_em:parseFloat(getComputedStyle(warning).letterSpacing)/parseFloat(getComputedStyle(warning).fontSize),cue_alpha:parseFloat(getComputedStyle(cue).opacity)});
    }
    return {reduced,transitions,location_duration:parseFloat(getComputedStyle(document.querySelector('.loc-card b')).animationDuration),samples};
   },reduced));
  }
  await page.emulateMedia({reducedMotion:'no-preference'});await page.setContent(`<style>${css}</style><div class="menu"><div class="m-veil" style="opacity:0"></div></div>`);
  await page.evaluate(()=>{const n=document.querySelector('.m-veil');getComputedStyle(n).opacity;n.style.opacity='1';});
  await page.evaluate(()=>new Promise(requestAnimationFrame));
  const before=await page.evaluate(()=>{const n=document.querySelector('.m-veil'),a=n.getAnimations()[0];if(!a)throw Error('No original veil transition');a.pause();a.currentTime=100;return {duration_ms:a.effect.getTiming().duration,opacity:parseFloat(getComputedStyle(n).opacity)};});
  await page.emulateMedia({reducedMotion:'reduce'});
  const during=await page.evaluate(()=>{const n=document.querySelector('.m-veil'),a=n.getAnimations()[0];return {duration_ms:a.effect.getTiming().duration,opacity:parseFloat(getComputedStyle(n).opacity)};});
  const reversed=await page.evaluate(()=>{const n=document.querySelector('.m-veil');n.style.opacity='0';getComputedStyle(n).opacity;const a=n.getAnimations()[0];if(!a)throw Error('No reversed veil transition');a.pause();a.currentTime=0;return {duration_ms:a.effect.getTiming().duration};});
  if(profiles[1].transitions.toggle.some(v=>v!==.12)||profiles[1].transitions.hud[0]!==.35||during.duration_ms!==500)throw Error('Original motion preference boundary changed');
  fs.writeFileSync(path.join(root,'assets/export/fixtures/motion-preference-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),profiles,live_switch:{before,during,reversed}},null,2)+'\n');console.log(JSON.stringify({profiles:profiles.length,live_switch:{before,during,reversed}}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
