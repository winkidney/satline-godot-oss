const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'../..');const bead=process.argv.includes('--bead-components');
 const files={
 '/saltline-godot/tools/wet_reference.html':'saltline-godot/tools/wet_reference.html',
 '/artifact-rendering-study/source/extracted/bundle-1.js':'artifact-rendering-study/source/extracted/bundle-1.js',
 '/saltline-godot/assets/export/fixtures/source-wet-original.glsl':'saltline-godot/assets/export/fixtures/source-wet-original.glsl',
 '/saltline-godot/assets/export/fixtures/source-wet-noise-original.glsl':'saltline-godot/assets/export/fixtures/source-wet-noise-original.glsl'};
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--use-angle=gl','--ignore-gpu-blocklist']});
 try{
  const page=await browser.newPage();
  await page.route('**/*',async route=>{const file=files[new URL(route.request().url()).pathname];if(!file){await route.abort();return;}let body=fs.readFileSync(path.join(root,file));if(bead&&file.endsWith('wet_reference.html'))body=body.toString().replace('gl_FragColor=vec4(slWetK,slUp,slBead,sampledDiffuseColor.r);','gl_FragColor=vec4(slN3(uPos*170.0),slN3(uPos*410.0+5.0),slBead,slWetK);');await route.fulfill({status:200,contentType:file.endsWith('.html')?'text/html':'text/plain',body});});
  await page.goto('http://saltline-reference.invalid/saltline-godot/tools/wet_reference.html');
  const result=await page.evaluate(async()=>await window.ready);
  if(!result.backend.renderer.includes('NVIDIA')||!result.backend.renderer.includes('OpenGL'))throw Error('Unexpected reference backend: '+result.backend.renderer);
  result.inputs=Object.values(files).map(file=>({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex')}));
  fs.writeFileSync(path.join(root,'saltline-godot/assets/export/fixtures/'+(bead?'wet-bead-components-nvidia-gl.json':'wet-reference-nvidia-gl.json')),JSON.stringify(result,null,2));
  console.log(JSON.stringify({cases:result.cases.length,backend:result.backend}));
 }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exit(1)});
