const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),html=fs.readFileSync(path.join(root,'../artifact-rendering-study/source/saltline.original.html'),'utf8');
 const css=html.slice(html.indexOf('<style>')+7,html.indexOf('</style>'));
 const font=fs.readFileSync(path.join(root,'assets/fonts/barlow-condensed-500.ttf')).toString('base64');
 const text='Control to Saltline. Cross the berth, cut the three relays and reach the extraction boat. Stay clear of the water.';
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox']});
 try{
  const page=await browser.newPage(),cases=[];
  for(const [index,width] of [360,760,761,1280,360].entries()){
   const sampleText=index===4?'relays and reach the extraction boat. Stay clear of':text;
   await page.setViewportSize({width,height:720});
   await page.setContent(`<style>${css}@font-face{font-family:'Barlow Condensed';font-weight:500;src:url(data:font/ttf;base64,${font})}</style><div class="comms on"><span class="comms-who">CONTROL</span><span class="comms-t"></span></div>`);
   await page.locator('.comms-t').evaluate((node,text)=>node.textContent=text,sampleText);
   await page.evaluate(()=>document.fonts.ready);
   cases.push(await page.evaluate(()=>{
    const node=document.querySelector('.comms-t'),s=getComputedStyle(node),lines=[];
    for(let i=0;i<node.textContent.length;i++){
     const range=document.createRange();range.setStart(node.firstChild,i);range.setEnd(node.firstChild,i+1);const rect=range.getBoundingClientRect();
     let line=lines.find(line=>Math.abs(line.y-rect.y)<1);if(!line){line={y:rect.y,text:'',left:rect.left,right:rect.right};lines.push(line);}line.text+=node.textContent[i];line.right=rect.right;
    }
    return {width:innerWidth,text:node.textContent,pixels:parseFloat(s.fontSize),spacing:parseFloat(s.letterSpacing),line_height:parseFloat(s.lineHeight),lines:lines.map(line=>line.text.trim()),line_widths:lines.map(line=>line.right-line.left)};
   }));
  }
  if(cases[1].pixels!==17||cases[2].pixels!==19)throw Error('Original responsive boundary changed');
  fs.writeFileSync(path.join(root,'assets/export/fixtures/radio-layout-reference.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),text,cases,scope:'Original HTML CSS and original local font in Chrome; actual computed typography and character-range line wrapping.'},null,2)+'\n');
  console.log(JSON.stringify(cases));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
