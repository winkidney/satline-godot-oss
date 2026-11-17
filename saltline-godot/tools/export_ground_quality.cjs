const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'../..'),quality=process.argv.find(x=>x.startsWith('--quality='))?.slice(10)||'low';
 if(!['low','high'].includes(quality))throw Error('Expected low or high');
 const out=path.join(root,'saltline-godot/assets/ground/'+quality);fs.mkdirSync(out,{recursive:true});
 const html=fs.readFileSync(path.join(root,'artifact-rendering-study/source/saltline.original.html'));
 let fontCss='';for(const [family,slug,weights] of [['Big Shoulders Display','big-shoulders-display',[500,700,900]],['IBM Plex Mono','ibm-plex-mono',[400,500]],['Barlow Condensed','barlow-condensed',[400,500,600]]])for(const weight of weights){const bytes=fs.readFileSync(path.join(root,'saltline-godot/assets/fonts',slug+'-'+weight+'.ttf'));fontCss+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${bytes.toString('base64')})}`;}
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--use-angle=gl','--ignore-gpu-blocklist']});
 try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='fonts.googleapis.com'?r.fulfill({status:200,contentType:'text/css',body:fontCss}):new URL(r.request().url()).pathname==='/saltline.original.html'?r.fulfill({status:200,contentType:'text/html',body:html}):r.abort());
 await page.goto('http://saltline-reference.invalid/saltline.original.html?q='+quality+'&shot=1&noaudio=1&step=1&dt=0.016666666666666666');await page.waitForFunction(()=>window.__ready&&window.__step===0,{timeout:180000});
 const data=await page.evaluate(()=>{
 const g=__G,T=g.THREE;let material;g.scene.traverse(n=>{if(n.material?.name==='apron_wet')material=n.material;});if(!material)throw Error('Missing apron');
 const patch={uniforms:{},vertexShader:T.ShaderLib.standard.vertexShader,fragmentShader:T.ShaderLib.standard.fragmentShader};material.onBeforeCompile(patch,g.renderer);
 const gl=g.renderer.getContext(),previous=gl.getParameter(gl.FRAMEBUFFER_BINDING),fbo=gl.createFramebuffer(),textures=[];
 function b64(a){let s='';for(let i=0;i<a.length;i+=32768)s+=String.fromCharCode(...a.subarray(i,i+32768));return btoa(s);}
 try{for(const name of ['uMask','uDetail','uDetailN','uMarks']){
 const tex=patch.uniforms[name].value;g.renderer.initTexture(tex);const w=tex.image.width,h=tex.image.height,levels=[];let width=w,height=h,level=0;
 while(true){gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,g.renderer.properties.get(tex).__webglTexture,level);if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)throw Error('Incomplete '+name);const a=new Uint8Array(width*height*4);gl.readPixels(0,0,width,height,gl.RGBA,gl.UNSIGNED_BYTE,a);if(gl.getError()!==gl.NO_ERROR)throw Error('Readback '+name);levels.push({width,height,base64:b64(a)});if(width===1&&height===1)break;width=Math.max(1,width>>1);height=Math.max(1,height>>1);level++;}
 textures.push({name,width:w,height:h,flipY:tex.flipY,wrapS:tex.wrapS,wrapT:tex.wrapT,minFilter:tex.minFilter,magFilter:tex.magFilter,anisotropy:tex.anisotropy,colorSpace:tex.colorSpace,levels,cpu:tex.image.data?b64(tex.image.data):null});
 }}finally{gl.bindFramebuffer(gl.FRAMEBUFFER,previous);gl.deleteFramebuffer(fbo);}
 const debug=gl.getExtension('WEBGL_debug_renderer_info');return {quality:g.quality,textures,mark_resolution:patch.uniforms.uMarkRes.value,backend:gl.getParameter(debug.UNMASKED_RENDERER_WEBGL)};
 });
 for(const t of data.textures){const source=[],flipped=[];for(const l of t.levels){const a=Buffer.from(l.base64,'base64'),b=Buffer.alloc(a.length),row=l.width*4;for(let y=0;y<l.height;y++)a.copy(b,y*row,(l.height-1-y)*row,(l.height-y)*row);source.push(a);flipped.push(b);l.bytes=a.length;delete l.base64;}
 const a=Buffer.concat(source),b=Buffer.concat(flipped),prefix='res://assets/ground/'+quality+'/'+t.name;
 t.id='ground-'+quality+'-'+t.name;t.godot_file=prefix+'.source-miprgba';t.godot_source_mip_file=t.godot_file;t.godot_mip_file=prefix+'.miprgba';t.godot_has_mipmaps=true;t.source_sha256=crypto.createHash('sha256').update(a).digest('hex');
 fs.writeFileSync(path.join(out,t.name+'.source-miprgba'),a);fs.writeFileSync(path.join(out,t.name+'.miprgba'),b);
 if(t.cpu){const cpu=Buffer.from(t.cpu,'base64');fs.writeFileSync(path.join(out,t.name+'.cpu-rgba'),cpu);t.cpu_file='res://assets/ground/'+quality+'/'+t.name+'.cpu-rgba';t.cpu_sha256=crypto.createHash('sha256').update(cpu).digest('hex');delete t.cpu;}
 }
 data.local_fonts=true;data.local_font_files_sha256=Object.fromEntries(fs.readdirSync(path.join(root,'saltline-godot/assets/fonts')).filter(f=>f.endsWith('.ttf')).map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'saltline-godot/assets/fonts',f))).digest('hex')]));data.source_sha256=crypto.createHash('sha256').update(html).digest('hex');data.errors=errors;fs.writeFileSync(path.join(out,'ground.json'),JSON.stringify(data,null,2));console.log(JSON.stringify({quality,textures:data.textures.map(t=>({name:t.name,size:t.width,levels:t.levels.length})),errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
