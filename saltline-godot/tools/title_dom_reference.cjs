const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('playwright');
(async()=>{
 const base=path.resolve(__dirname,'..'),original=fs.readFileSync(path.resolve(base,'../artifact-rendering-study/source/saltline.original.html'),'utf8'),source=fs.readFileSync(path.resolve(base,'../artifact-rendering-study/source/extracted/bundle-1.js'),'utf8');
 const constants=source.slice(source.indexOf('  var lT = "saltline.settings.v1"'),source.indexOf('  function iL() {'));
 const values=Function('zi',constants+';return [uT,ab,cT,fT];')({fov:74});
 const a=source.indexOf('(s.innerHTML = `',source.indexOf('function hT(n, e) {'))+'(s.innerHTML = '.length,b=source.indexOf('\n  `),',a)+4;
 const html=Function('uT','ab','cT','fT','sL','oL','rL','return '+source.slice(a,b))(...values,'','','');
 let css=original.slice(original.indexOf('<style>')+7,original.indexOf('</style>'));
 for(const [family,file,weight]of [['Big Shoulders Display','big-shoulders-display-900.ttf',900],['IBM Plex Mono','ibm-plex-mono-400.ttf',400],['IBM Plex Mono','ibm-plex-mono-500.ttf',500],['Barlow Condensed','barlow-condensed-500.ttf',500],['Barlow Condensed','barlow-condensed-600.ttf',600]])css+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${fs.readFileSync(path.join(base,'assets/fonts',file)).toString('base64')})}`;
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});const page=await browser.newPage();const rows=[];
 for(const [width,height]of [[1280,720],[960,540],[640,360],[320,568]]){
  await page.setViewportSize({width,height});await page.setContent(`<style>${css}</style><div id="app"><div id="ui"><div class="menu open" data-screen="title" data-mode="mission">${html}</div></div></div>`);await page.evaluate(()=>document.fonts.ready);
  await page.evaluate(()=>{document.querySelector('[data-f="modenote"]').textContent='Cut three relays and reach the boat. About five minutes.'});
  if(width===1280){
   const pick=await page.evaluate(()=>{const e=document.querySelector('.m-pick'),s=getComputedStyle(e);return{label_width:parseFloat(s.gridTemplateColumns),column_gap:parseFloat(s.columnGap),row_gap:parseFloat(s.rowGap),button_height:parseFloat(getComputedStyle(e.querySelector('button')).minHeight)}});pick.source_sha256=crypto.createHash('sha256').update(source).digest('hex');fs.writeFileSync(path.join(base,'assets/export/title-pick-metrics.json'),JSON.stringify(pick));
   const legend=await page.evaluate(()=>{
    const root=document.querySelector('.m-legend'),base=root.getBoundingClientRect(),glyphs=[],boxes=[];
    const color=value=>{const v=value.match(/[\d.]+/g).map(Number);return v.length===3?[...v,1]:v};
    for(const e of root.querySelectorAll('kbd,.lg-pad')){const r=e.getBoundingClientRect(),s=getComputedStyle(e);boxes.push({rect:[r.x-base.x,r.y-base.y,r.width,r.height],background:color(s.backgroundColor),border:color(s.borderTopColor),width:parseFloat(s.borderTopWidth),all:e.tagName==='KBD'});}
    const walk=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;const canvas=document.createElement('canvas'),context=canvas.getContext('2d');
    while(node=walk.nextNode()){if(!node.textContent.trim())continue;const style=getComputedStyle(node.parentElement);context.font=style.font;
     for(let i=0;i<node.textContent.length;i++){const range=document.createRange();range.setStart(node,i);range.setEnd(node,i+1);const r=range.getBoundingClientRect();if(r.width<=0)continue;let text=node.textContent[i];if(style.textTransform==='uppercase')text=text.toUpperCase();if(!text.trim())continue;glyphs.push({text,x:r.x-base.x,y:r.y-base.y+context.measureText(text).fontBoundingBoxAscent,font:style.fontFamily.includes('IBM Plex')?'mono':'label',pixels:parseFloat(style.fontSize),color:color(style.color)});}
    }
    return{width:base.width,height:base.height,glyphs,boxes};
   });legend.source_sha256=crypto.createHash('sha256').update(source).digest('hex');legend.css_sha256=crypto.createHash('sha256').update(original.slice(original.indexOf('<style>')+7,original.indexOf('</style>'))).digest('hex');legend.viewport=[1280,720];legend.fonts={};for(const file of ['barlow-condensed-500.ttf','ibm-plex-mono-500.ttf'])legend.fonts[file]=crypto.createHash('sha256').update(fs.readFileSync(path.join(base,'assets/fonts',file))).digest('hex');fs.writeFileSync(path.join(base,'assets/export/title-legend.json'),JSON.stringify(legend));
   await page.locator('.m-veil').evaluate(e=>e.style.visibility='hidden');await page.screenshot({path:path.join(base,'evidence/title-legend-source.png')});await page.locator('.m-veil').evaluate(e=>e.style.visibility='');
  }
  const boxes=await page.evaluate(()=>Object.fromEntries(['.m-legend','.m-title-main','.m-eyebrow','.m-word','.m-premise','.m-actions','.m-pick','.m-note'].map(selector=>{const e=document.querySelector(selector),r=e.getBoundingClientRect();return[selector,{x:r.x,y:r.y,width:r.width,height:r.height,font:getComputedStyle(e).fontSize}]})));
  const picks=await page.evaluate(()=>{const base=document.querySelector('.m-pick').getBoundingClientRect();return [...document.querySelectorAll('.m-pick label,.m-pick .seg button,.m-pick-note')].map(e=>{const r=e.getBoundingClientRect();return{text:e.textContent,x:r.x-base.x,y:r.y-base.y,width:r.width,height:r.height}})});
  rows.push({width,height,boxes,picks});await page.screenshot({path:path.join(base,`evidence/title-source-${width}x${height}.png`)});
 }
 const bars=await page.evaluate(async()=>{
  const top=document.querySelector('.m-bars i'),bottom=document.querySelector('.m-bars i+i');
  top.getBoundingClientRect();document.querySelector('.menu').dataset.screen='none';await new Promise(requestAnimationFrame);
  const animations=[top,bottom].map(e=>e.getAnimations()[0]);for(const a of animations){if(!a)throw Error('bar transition missing');a.pause();}
  const height=top.getBoundingClientRect().height,rows=[];
  for(const ms of [0,35,70,175,350,525,700]){for(const a of animations)a.currentTime=ms;const y=new DOMMatrixReadOnly(getComputedStyle(top).transform).m42;rows.push({ms,height,y,amount:1+y/(height*1.01)});}
  return rows;
 });
 fs.writeFileSync(path.join(base,'assets/export/fixtures/title-bars-css.json'),JSON.stringify({rows:bars}));
 await browser.close();fs.writeFileSync(path.join(base,'evidence/title-dom-reference.json'),JSON.stringify({scope:'Literal original menu template/CSS, bundled local fonts; static title DOM without game runtime.',rows},null,2));console.log(JSON.stringify(rows));
})().catch(e=>{console.error(e);process.exitCode=1});
