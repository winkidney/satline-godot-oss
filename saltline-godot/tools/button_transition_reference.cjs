const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {chromium}=require('playwright');
(async()=>{
 const base=path.resolve(__dirname,'..'),html=fs.readFileSync(path.resolve(base,'../artifact-rendering-study/source/saltline.original.html'),'utf8'),css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});const page=await browser.newPage({viewport:{width:1280,height:720}});const cases=[];
 for(const primary of [false,true]){
  await page.mouse.move(1000,600);await page.setContent(`<style>${css}</style><div id="app"><button id="probe" class="btn ${primary?'primary':''}">${primary?'Deploy':'Settings'}</button></div>`);
  const start=await page.locator('#probe').evaluate(e=>{const s=getComputedStyle(e);return[s.backgroundColor,s.borderTopColor,s.color]});
  await page.hover('#probe');
  const samples=await page.locator('#probe').evaluate(async e=>{await new Promise(requestAnimationFrame);const a=e.getAnimations();if(!a.length)throw Error('No transitions');for(const item of a)item.pause();const rows=[];for(const ms of [0,12,24,30,60,90,120]){for(const item of a)item.currentTime=ms;const s=getComputedStyle(e);rows.push({ms,raw:[s.backgroundColor,s.borderTopColor,s.color]})}return rows;});
  const color=s=>{const values=s.match(/[\d.]+/g).map(Number);if(!s.startsWith('color('))for(let i=0;i<3;i++)values[i]/=255;return values.length===3?[...values,1]:values};
  cases.push({primary,start:start.map(color),target:samples.at(-1).raw.map(color),rows:samples.map(row=>({...row,colors:row.raw.map(color)}))});
 }
 await browser.close();const result={cases,css_sha256:crypto.createHash('sha256').update(css).digest('hex'),scope:'Actual original .btn/:hover CSS transitions sampled in Chrome; unchanged colors included. No pointer reversal or active-state interruption.'};fs.writeFileSync(path.join(base,'assets/export/fixtures/button-transition-css.json'),JSON.stringify(result));console.log(JSON.stringify(result));
})().catch(e=>{console.error(e);process.exitCode=1});
