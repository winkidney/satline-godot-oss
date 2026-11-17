const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8');
 let css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 for(const [family,file,weight] of [['Barlow Condensed','barlow-condensed',600],['Big Shoulders Display','big-shoulders-display',700],['IBM Plex Mono','ibm-plex-mono',500]])css+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(root,'assets/fonts',`${file}-${weight}.ttf`)).toString('base64')})}`;
 const text='CUT THE RELAYS AND REACH THE EXTRACTION BOAT';
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),cases=[];
  for(const width of [360,760,761,1280])for(const touch of [false,true]){
   await page.setViewportSize({width,height:720});
   await page.setContent(`<style>${css}</style><div id="app" class="${touch?'is-touch':''}"><div class="hud on"><div class="h-compass"><div class="h-heading">000</div></div><div class="h-obj has"><div class="h-k">Objective</div><div class="h-obj-t">${text}</div><div class="h-relays"><span>Relays</span><i></i><i></i><i></i><b>0/3</b></div></div><div class="h-health on"><div class="h-k">Vitals</div><div class="h-hp-row"><b class="h-hp-n">70</b><div class="h-hp-bar"><i></i></div></div></div><div class="h-ammo low"><div class="h-cue on">Low ammo</div><div class="h-ammo-row"><b class="h-ammo-n">01</b><span class="h-ammo-r">090</span></div><div class="h-pips">${'<i></i>'.repeat(30)}</div><div class="h-wname">A1</div><div class="h-alt">Pistol</div></div></div></div>`);
   await page.evaluate(()=>document.fonts.ready);
   cases.push(await page.evaluate(({width,touch})=>{
    const box=selector=>{const n=document.querySelector(selector),s=getComputedStyle(n),r=n.getBoundingClientRect();return {top:r.top,pixels:parseFloat(s.fontSize),spacing:parseFloat(s.letterSpacing),display:s.display,max_width:s.maxWidth};};
    const n=document.querySelector('.h-obj-t'),lines=[];
    for(let i=0;i<n.textContent.length;i++){const r=document.createRange();r.setStart(n.firstChild,i);r.setEnd(n.firstChild,i+1);const rect=r.getBoundingClientRect();let line=lines.find(line=>Math.abs(line.y-rect.y)<1);if(!line){line={y:rect.y,text:''};lines.push(line);}line.text+=n.textContent[i];}
    return {width,touch,objective:box('.h-obj'),objective_text:box('.h-obj-t'),objective_lines:lines.map(line=>line.text.trim()),relays:box('.h-relays'),heading:box('.h-heading'),ammo:box('.h-ammo'),ammo_text:box('.h-ammo-n'),cue:box('.h-cue'),health:box('.h-health')};
   },{width,touch}));
  }
  if(cases[2].ammo_text.pixels!==56||cases[3].ammo_text.pixels!==44)throw Error('Original CSS specificity changed');
  fs.writeFileSync(path.join(root,'assets/export/fixtures/responsive-hud-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),text,cases},null,2)+'\n');console.log(JSON.stringify({cases:cases.length}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
