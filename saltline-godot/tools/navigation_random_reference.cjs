const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'));
 let css='';for(const [family,slug,weights]of [['Big Shoulders Display','big-shoulders-display',[500,700,900]],['IBM Plex Mono','ibm-plex-mono',[400,500]],['Barlow Condensed','barlow-condensed',[400,500,600]]])for(const weight of weights)css+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(root,'assets/fonts',slug+'-'+weight+'.ttf')).toString('base64')})}`;
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--use-angle=gl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.addInitScript(()=>{
   const original=Math.random,probe={enabled:false,cursor:0,tape:[]};window.__navigationRandomProbe=probe;
   Math.random=function(){if(!probe.enabled)return original();if(probe.cursor>=probe.tape.length)throw Error('Navigation random tape exhausted');return probe.tape[probe.cursor++];};
  });
  await page.route('**/*',r=>new URL(r.request().url()).hostname==='fonts.googleapis.com'?r.fulfill({status:200,contentType:'text/css',body:css}):new URL(r.request().url()).pathname==='/saltline.original.html'?r.fulfill({status:200,contentType:'text/html',body:html}):r.abort());
  await page.goto('http://saltline-reference.invalid/saltline.original.html?q=high&noaudio=1&shot=1&step=1&dt=0.016666666666666666');
  await page.waitForFunction(()=>window.__ready&&window.__step===0,{timeout:180000});
  const data=await page.evaluate(()=>{
   const probe=window.__navigationRandomProbe;let seed=71293;for(let i=0;i<512;i++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;probe.tape.push(seed/4294967296);}
   const rows=[],g=__G,T=g.THREE;probe.enabled=true;
   for(const input of [{kind:'point',origin:[-32,0,6],radius:7},{kind:'smoke'},{kind:'point',origin:[-32,0,6],radius:7},{kind:'random'},{kind:'point',origin:[-100,0,-100],radius:.1},{kind:'smoke'},{kind:'point',origin:[-39.75,0,-31.75],radius:0},{kind:'random'}]){
    const before=probe.cursor;let result=null;
    if(input.kind==='point')result=g.physics.nav.randomPoint(new T.Vector3(...input.origin),input.radius).toArray();
    else if(input.kind==='smoke')g.fx.smoke(new T.Vector3(-32,1,6),{count:1,size:.5,life:1,color:0x202020});
    else result=Math.random();
    rows.push({input,result,calls:probe.cursor,draws:probe.cursor-before});
   }
   const input={kind:"point",origin:rows[0].result,radius:0},before=probe.cursor;const result=g.physics.nav.randomPoint(new T.Vector3(...input.origin),input.radius).toArray();rows.push({input,result,calls:probe.cursor,draws:probe.cursor-before});
   probe.enabled=false;return {tape:probe.tape,rows,calls:probe.cursor};
  });
  if(errors.length)throw Error(errors.join('\n'));
  data.source_sha256=crypto.createHash('sha256').update(html).digest('hex');data.scope='Actual original Main nav.randomPoint interleaved with actual fx.smoke and direct Math.random; permanent wrapper installed before bundle aliases capture it, tape enabled only after ready. Full original grid/collision; no source file edits.';
  fs.writeFileSync(path.join(root,'assets/export/fixtures/navigation-random-reference.json'),JSON.stringify(data,null,2));console.log(JSON.stringify({calls:data.calls,rows:data.rows.map(r=>({kind:r.input.kind,draws:r.draws}))}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
