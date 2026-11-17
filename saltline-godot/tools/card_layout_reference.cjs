const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8'),bundle=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
 let css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 for(const [family,file,weights] of [['Barlow Condensed','barlow-condensed',[500,600]],['Big Shoulders Display','big-shoulders-display',[900]],['IBM Plex Mono','ibm-plex-mono',[400,500]]])for(const weight of weights)css+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(root,'assets/fonts',`${file}-${weight}.ttf`)).toString('base64')})}`;
 const sections=bundle.slice(bundle.indexOf('    <section class="m-screen m-card"'),bundle.indexOf('    <div class="panel" role="dialog"')).replaceAll('\\xB7','·');
 if(!sections.includes('data-s="complete"'))throw Error('Original card markup anchor changed');
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),cases=[];
  for(const [width,height] of [[1280,720],[360,720],[640,360],[640,240]])for(const [screen,mode] of [['paused','mission'],['dead','mission'],['dead','holdout'],['complete','mission']]){
   await page.setViewportSize({width,height});await page.setContent(`<style>${css}</style><div id="app"><div class="menu" data-screen="${screen}" data-mode="${mode}">${sections}</div></div>`);
   await page.evaluate(({screen,mode})=>{const c=document.querySelector(`[data-s="${screen}"]`);c.querySelectorAll('[data-only]').forEach(n=>{if(n.dataset.only!==mode)n.style.display='none';});const line=c.querySelector('.m-line');if(line)line.textContent='Resume recaptures the mouse.';},{screen,mode});
   await page.evaluate(()=>document.fonts.ready);
   cases.push(await page.evaluate(({width,height,screen,mode})=>{
    const c=document.querySelector(`[data-s="${screen}"]`),r=c.getBoundingClientRect(),h=getComputedStyle(c.querySelector('.m-h')),rating=c.querySelector('.m-rating b');
    return {width,height,screen,mode,card:{x:r.x,y:r.y,width:r.width,height:r.height},heading_pixels:parseFloat(h.fontSize),rating_pixels:rating?parseFloat(getComputedStyle(rating).fontSize):null,scroll_height:c.scrollHeight,client_height:c.clientHeight,button_heights:[...c.querySelectorAll('button')].map(n=>n.getBoundingClientRect().height),button_widths:[...c.querySelectorAll('button')].map(n=>n.getBoundingClientRect().width),content:[...c.children].map(n=>({tag:n.tagName,cls:n.className,height:n.getBoundingClientRect().height,margin_top:getComputedStyle(n).marginTop,margin_bottom:getComputedStyle(n).marginBottom}))};
   },{width,height,screen,mode}));
  }
  fs.writeFileSync(path.join(root,'assets/export/fixtures/card-layout-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),cases},null,2)+'\n');console.log(JSON.stringify({cases:cases.length}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
