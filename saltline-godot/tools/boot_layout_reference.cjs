const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8'),bundle=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
 let css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 for(const [family,file,weight] of [['Big Shoulders Display','big-shoulders-display',900],['IBM Plex Mono','ibm-plex-mono',400]])css+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(root,'assets/fonts',`${file}-${weight}.ttf`)).toString('base64')})}`;
 const stages=[...bundle.slice(bundle.indexOf('    if (\n      (await fa("Waking'),bundle.indexOf('    let l = performance.now()',bundle.indexOf('async function cL()'))).matchAll(/fa\("([^"]+)",\s*(0?\.\d+|1)\)/g)].map(m=>({message:m[1],progress:Number(m[2])}));
 if(stages.length!==10)throw Error('Original boot stages changed: '+stages.length);
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),cases=[];
  for(const width of [1280,360])for(const reduced of [false,true]){
   await page.setViewportSize({width,height:720});await page.emulateMedia({reducedMotion:reduced?'reduce':'no-preference'});
   await page.setContent(`<style>${css}</style><div id="app"><div id="boot"><div class="boot-mark">SALTLINE</div><div class="boot-sub">Raising the terminal</div><div class="boot-bar"><i></i></div></div></div>`);await page.evaluate(()=>document.fonts.ready);
   cases.push(await page.evaluate(({width,reduced})=>{
    const rect=selector=>{const n=document.querySelector(selector),r=n.getBoundingClientRect(),s=getComputedStyle(n);return {x:r.x,y:r.y,width:r.width,height:r.height,pixels:parseFloat(s.fontSize)};};
    return {width,reduced,mark:rect('.boot-mark'),subtitle:rect('.boot-sub'),bar:rect('.boot-bar'),fade_duration:parseFloat(getComputedStyle(document.querySelector('#boot')).transitionDuration),bar_duration:parseFloat(getComputedStyle(document.querySelector('.boot-bar i')).transitionDuration)};
   },{width,reduced}));
  }
  fs.writeFileSync(path.join(root,'assets/export/fixtures/boot-layout-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),stages,cases},null,2)+'\n');console.log(JSON.stringify({stages,cases}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
