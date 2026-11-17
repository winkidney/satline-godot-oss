const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'../..');const out=path.join(root,'saltline-godot/evidence');
 const mode=process.argv.find(x=>x.startsWith("--surface="))?.slice(10)||"";const noMsaa=process.argv.includes("--no-msaa");const suffix=(mode?"-"+mode:"")+(noMsaa?"-no-msaa":"");
 const html=fs.readFileSync(path.join(root,'artifact-rendering-study/source/saltline.original.html'));
 let fontCss='';for(const [family,slug,weights] of [['Big Shoulders Display','big-shoulders-display',[500,700,900]],['IBM Plex Mono','ibm-plex-mono',[400,500]],['Barlow Condensed','barlow-condensed',[400,500,600]]])for(const weight of weights){const bytes=fs.readFileSync(path.join(root,'saltline-godot/assets/fonts',slug+'-'+weight+'.ttf'));fontCss+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${bytes.toString('base64')})}`;}

 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--use-angle=gl','--ignore-gpu-blocklist']});
 try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='fonts.googleapis.com'?r.fulfill({status:200,contentType:'text/css',body:fontCss}):new URL(r.request().url()).pathname==='/saltline.original.html'?r.fulfill({status:200,contentType:'text/html',body:html}):r.abort());
 await page.goto('http://saltline-reference.invalid/saltline.original.html?q=high&show=weapon&wgun=rifle&wpose=side&shot=1&noaudio=1&step=1&dt=0.016666666666666666');
 await page.waitForFunction(()=>window.__ready&&window.__step===0,{timeout:180000});
 if(noMsaa)await page.evaluate(()=>__G.render.setQuality({...__G.quality,msaa:0}));
 if(mode)await page.evaluate(mode=>{
  if(mode.startsWith('triangle-'))__G.scene.traverse(n=>{if(n.material?.name!=='pac9_anodised')return;const geo=n.geometry.clone();if(geo.index)throw Error('Expected original nonindexed gun geometry');const count=geo.attributes.position.count,ids=new Float32Array(count);for(let i=0;i<count;i++)ids[i]=Math.floor(i/3);geo.setAttribute('aProbeID',new __G.THREE.BufferAttribute(ids,1));n.geometry=geo;});
  const seen=new Set();__G.scene.traverse(n=>{const m=n.material;if(!m||(!mode.startsWith("coverage")&&!mode.startsWith("triangle-")&&m.name!=="pac9_anodised")||seen.has(m))return;seen.add(m);
   const old=m.onBeforeCompile,key=m.customProgramCacheKey.bind(m);m.customProgramCacheKey=()=>key()+":studio-"+mode;
   m.onBeforeCompile=function(shader,renderer){old.call(this,shader,renderer);if(mode.startsWith('triangle-')&&m.name==='pac9_anodised'){
    shader.vertexShader='attribute float aProbeID;flat varying float probeID;\n'+shader.vertexShader;
    shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\nprobeID=aProbeID;');
    shader.fragmentShader='flat varying float probeID;\n'+shader.fragmentShader;
   }
   if(mode==='coverage-flat'&&m.name==='pac9_anodised'){
    shader.vertexShader='flat varying float coverageFace;\n'+shader.vertexShader;
    shader.vertexShader=shader.vertexShader.replace('#include <begin_vertex>','#include <begin_vertex>\ncoverageFace=step(-.03,position.x);');
    shader.fragmentShader='flat varying float coverageFace;\n'+shader.fragmentShader;
   }
   const value=mode==="triangle-confirm"?(m.name==="pac9_anodised"?"vec3(probeID==614.?1.:0.,0.,0.)":"vec3(0.)"):mode==="triangle-other-id"?(m.name==="pac9_anodised"?"vec3((probeID!=607.&&probeID!=339.&&probeID!=171.&&probeID!=612.&&probeID!=613.)?probeID:0.,0.,0.)":"vec3(0.)"):mode==="triangle-rest"?(m.name==="pac9_anodised"?"vec3(probeID==612.?1.:0.,probeID==613.?1.:0.,(probeID!=607.&&probeID!=339.&&probeID!=171.&&probeID!=612.&&probeID!=613.)?1.:0.)":"vec3(0.)"):mode==="triangle-domain"?(m.name==="pac9_anodised"?"(probeID==339.?dQ*34.:vec3(0.))":"vec3(0.)"):mode==="triangle-mask"?(m.name==="pac9_anodised"?"vec3(probeID==607.?1.:0.,probeID==339.?1.:0.,probeID==171.?1.:0.)":"vec3(0.)"):mode==="coverage-flat"?(m.name==="pac9_anodised"?"vec3(coverageFace,1.-coverageFace,0.)":"vec3(0.,0.,1.)"):mode==="coverage"?(m.name==="pac9_anodised"?"vec3(step(-.03,dP.x),1.-step(-.03,dP.x),0.)":"vec3(0.,0.,1.)"):mode==="domain"?"dQ*34.":mode==="noise"?"vec3(dLo,dMid,dRun)":mode==="grain"?"vec3(dGr+.5,dNear,dDrop)":mode==="inputs"?"vec3(dPx*1000.,dNear,dWet)":mode==="normal"?"normalize(normal)*.5+.5":mode==="roughness"?"vec3(roughnessFactor)":mode==="direct-specular"?"reflectedLight.directSpecular":"reflectedLight.indirectSpecular";shader.fragmentShader=shader.fragmentShader.replace("#include <opaque_fragment>","gl_FragColor=vec4("+value+",1.);return;");};m.needsUpdate=true;
  });
 },mode);
 if(mode)await page.evaluate(()=>{const g=__G,render=g.renderer.render.bind(g.renderer);g.renderer.render=function(scene,camera){const result=render(scene,camera),target=this.getRenderTarget();if(scene===g.scene&&camera===g.camera&&target?.texture.type===g.THREE.HalfFloatType){const raw=new Uint16Array(target.width*target.height*4);this.readRenderTargetPixels(target,0,0,target.width,target.height,raw);const bytes=new Uint8Array(raw.buffer);let text="";for(let i=0;i<bytes.length;i+=32768)text+=String.fromCharCode(...bytes.subarray(i,i+32768));const gl=this.getContext(),savedDraw=gl.getParameter(gl.DRAW_FRAMEBUFFER_BINDING),savedRead=gl.getParameter(gl.READ_FRAMEBUFFER_BINDING),msaa=this.properties.get(target).__webglMultisampledFramebuffer;let samples=0;const positions=[];if(msaa){gl.bindFramebuffer(gl.FRAMEBUFFER,msaa);samples=gl.getParameter(gl.SAMPLES);if(typeof gl.getMultisampleParameter==="function")for(let i=0;i<samples;i++)positions.push(Array.from(gl.getMultisampleParameter(gl.SAMPLE_POSITION,i)));gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER,savedDraw);gl.bindFramebuffer(gl.READ_FRAMEBUFFER,savedRead);}window.__studioHdr={width:target.width,height:target.height,base64:btoa(text),samples,sample_positions:positions,sample_positions_available:typeof gl.getMultisampleParameter==="function"};}return result;};});
 const data=await page.evaluate(()=>{
  const g=__G;g.render.autoExposure=false;g.render.exposure=1;g.render.fade=0;
  for(let i=0;i<12;i++)g.render.frame(0);
  const nodes=[];g.scene.traverse(n=>{if(n.isMesh)nodes.push({name:n.name,visible:n.visible,layers:n.layers.mask,material:n.material?.name})});
  const gl=g.renderer.getContext(),ext=gl.getExtension('WEBGL_debug_renderer_info');
  const ray=new g.THREE.Raycaster();ray.setFromCamera(new g.THREE.Vector2((660+.5)/1280*2-1,1-(359+.5)/720*2),g.camera);
  const hits=ray.intersectObjects(g.scene.children,true).filter(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;return true}).slice(0,4).map(h=>({name:h.object.name,material:h.object.material?.name,type:h.object.material?.type,object_uuid:h.object.uuid,geometry_uuid:h.object.geometry?.uuid,point:h.point.toArray(),uv:h.uv?.toArray()}));
  const coverageRays={};
  for(const [label,flipped] of [['pattern',false],['pattern_y_flip',true]]){
   coverageRays[label]=[[.375,.125],[.875,.375],[.125,.625],[.625,.875]].map(([x,y])=>{
    if(flipped)y=1-y;
    const ray=new g.THREE.Raycaster();ray.setFromCamera(new g.THREE.Vector2((660+x)/1280*2-1,1-(359+y)/720*2),g.camera);
    const hit=ray.intersectObjects(g.scene.children,true).find(h=>{for(let n=h.object;n;n=n.parent)if(!n.visible)return false;return true});
    if(!hit)return {x,y,hit:false};
    const local=hit.object.worldToLocal(hit.point.clone()),pos=hit.object.geometry.attributes.position;
    return {x,y,object_uuid:hit.object.uuid,material:hit.object.material?.name,faceIndex:hit.faceIndex,local:local.toArray(),triangle_x:hit.face?[hit.face.a,hit.face.b,hit.face.c].map(i=>pos.getX(i)):[],class:local.x>=-.03?'R':'G'};
   });
  }
  const bones=[];g.scene.traverse(n=>{if(n.isBone){let arm=n;while(arm&&!arm.name.startsWith("arm-"))arm=arm.parent;bones.push({side:arm?.name,name:n.name,p:n.position.toArray(),q:n.quaternion.toArray()})}});
  return {hits,coverageRays,bones,camera:{p:g.camera.position.toArray(),q:g.camera.quaternion.toArray(),fov:g.camera.fov},time:g.time,quality:g.quality,viewFill:g.render.viewFill,nodes,errors:[],backend:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):''};
 });
 if(process.argv.includes('--triangle-replay')){
 const input=JSON.parse(fs.readFileSync(path.join(out,'face614-replay-input.json'),'utf8'));
 const result=await page.evaluate(input=>{
  const g=__G,T=g.THREE,r=g.renderer,previous=r.getRenderTarget(),tone=r.toneMapping,clear=r.getClearColor(new T.Color()).clone(),alpha=r.getClearAlpha();
  const target=new T.WebGLRenderTarget(1280,720,{type:T.HalfFloatType,depthBuffer:false});target.samples=4;
  const scene=new T.Scene(),camera=new T.Camera(),geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(input.positions.flat(),3));
  const material=new T.ShaderMaterial({vertexShader:'void main(){gl_Position=vec4(position,1.);}',fragmentShader:'void main(){gl_FragColor=vec4(1.);}',depthTest:false,depthWrite:false,side:T.DoubleSide,toneMapped:false});const node=new T.Mesh(geometry,material);node.frustumCulled=false;scene.add(node);
  const raw=new Uint16Array(4);let value;
  try{r.toneMapping=T.NoToneMapping;r.setClearColor(0,0);r.setRenderTarget(target);r.clear();r.render(scene,camera);r.readRenderTargetPixels(target,660,360,1,1,raw);const bits=raw[0],exp=(bits>>10)&31,mant=bits&1023;value=exp?Math.pow(2,exp-15)*(1+mant/1024):Math.pow(2,-14)*mant/1024;}
  finally{r.setRenderTarget(previous);r.toneMapping=tone;r.setClearColor(clear,alpha);geometry.dispose();material.dispose();target.dispose();}
  return {weight:value,raw:Array.from(raw),samples:4,scope:'Same WebGL renderer/context, CPU-NDC single triangle, constant output, no depth.'};
 },input);
 fs.writeFileSync(path.join(out,'face614-source-replay.json'),JSON.stringify(result,null,2));
 }
 if(process.argv.includes('--sample-layout')){
 const layout=await page.evaluate(()=>{
  const g=__G,T=g.THREE,r=g.renderer,previous=r.getRenderTarget(),tone=r.toneMapping,clear=r.getClearColor(new T.Color()).clone(),alpha=r.getClearAlpha();
  const target=new T.WebGLRenderTarget(1,1,{type:T.HalfFloatType,depthBuffer:false});target.samples=4;
  const scene=new T.Scene(),camera=new T.OrthographicCamera(-1,1,1,-1,.1,10);camera.position.z=1;
  const material=new T.MeshBasicMaterial({color:0xffffff,toneMapped:false,depthTest:false,depthWrite:false,side:T.DoubleSide});
  const plane=new T.Mesh(new T.PlaneGeometry(2,2),material);scene.add(plane);const grid=[];
  r.toneMapping=T.NoToneMapping;r.setClearColor(0,0);
  try{for(let y=0;y<=8;y++){const row=[];for(let x=0;x<=8;x++){plane.scale.set(x/8,y/8,1);plane.position.set(-1+x/8,-1+y/8,0);r.setRenderTarget(target);r.clear();r.render(scene,camera);const raw=new Uint16Array(4);r.readRenderTargetPixels(target,0,0,1,1,raw);const bits=raw[0],exp=(bits>>10)&31,mant=bits&1023;const value=exp?Math.pow(2,exp-15)*(1+mant/1024):Math.pow(2,-14)*mant/1024;row.push(value);}grid.push(row);}}
  finally{r.setRenderTarget(previous);r.toneMapping=tone;r.setClearColor(clear,alpha);plane.geometry.dispose();material.dispose();target.dispose();}
  return {grid,threshold_step:.125,origin:'WebGL bottom-left',samples:4,method:'Geometry quadrant boundary scan, actual same renderer/context, HalfFloat render target; values are resolved coverage.'};
 });
 fs.writeFileSync(path.join(out,'weapon-studio-source-sample-layout.json'),JSON.stringify(layout,null,2));
 }
 await page.addStyleTag({content:'#ui,#boot{display:none!important}'});await page.screenshot({path:path.join(out,'weapon-studio-rifle-side-source'+suffix+'.png')});if(mode){const hdr=await page.evaluate(()=>__studioHdr);hdr.file='weapon-studio-rifle-side-source'+suffix+'.rgba16f';fs.writeFileSync(path.join(out,hdr.file),Buffer.from(hdr.base64,'base64'));delete hdr.base64;hdr.row_order='bottom-to-top';data.hdr=hdr;}
 data.errors=errors;data.source_sha256=crypto.createHash("sha256").update(html).digest("hex");
 fs.writeFileSync(path.join(out,'weapon-studio-rifle-side-source'+suffix+'.json'),JSON.stringify(data,null,2));console.log(JSON.stringify({camera:data.camera,time:data.time,viewFill:data.viewFill,meshes:data.nodes.length,errors}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
