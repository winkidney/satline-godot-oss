const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('playwright');
(async()=>{
 const root=path.resolve(__dirname,'../..'),quality=process.argv.find(x=>x.startsWith('--quality='))?.slice(10)||'low';
 if(!['low','high'].includes(quality))throw Error('Expected low or high');
 const caseName=process.argv.find(x=>x.startsWith('--case='))?.slice(7)||'';if(caseName&&!/^[a-z0-9-]+$/.test(caseName))throw Error('Invalid case');const camera=process.argv.find(x=>x.startsWith('--cam='))?.slice(6)||'-20,1.7,0,20,1.7,0';if(camera.split(',').length!==6||camera.split(',').some(x=>!Number.isFinite(Number(x))))throw Error('Invalid camera');const tag=quality+(caseName?'-'+caseName:'');
 const showcase=process.argv.find(x=>x.startsWith('--show='))?.slice(7)||'';if(showcase&&!['level','backdrop','enemies'].includes(showcase))throw Error('Unsupported paired showcase');const backdropPart=process.argv.find(x=>x.startsWith('--bshow='))?.slice(8)||'';if(backdropPart&&!['crane','ship','boat','sky'].includes(backdropPart))throw Error('Invalid backdrop selector');
 const enemyPart=process.argv.find(x=>x.startsWith('--eshow='))?.slice(8)||'both';if(!['both','gull','hound','fight','dead'].includes(enemyPart))throw Error('Invalid enemy selector');
 const captureEnemyNav=process.argv.includes('--enemy-nav-tape');
 const out=path.join(root,'saltline-godot/evidence');fs.mkdirSync(out,{recursive:true});
 const html=fs.readFileSync(path.join(root,'artifact-rendering-study/source/saltline.original.html'));
 let fontCss='';for(const [family,slug,weights] of [['Big Shoulders Display','big-shoulders-display',[500,700,900]],['IBM Plex Mono','ibm-plex-mono',[400,500]],['Barlow Condensed','barlow-condensed',[400,500,600]]])for(const weight of weights){const bytes=fs.readFileSync(path.join(root,'saltline-godot/assets/fonts',slug+'-'+weight+'.ttf'));fontCss+=`@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${bytes.toString('base64')})}`;}
 let servedHtml=html;if(captureEnemyNav){const start='async function KD(n){let e=await W5(n);';const instrumented='async function KD(n){const nav=n.physics.nav,randomPoint=nav.randomPoint;window.__enemyNavTape=[];nav.randomPoint=function(from,radius){const result=randomPoint.call(this,from,radius);window.__enemyNavTape.push({from:from.toArray(),radius,result:result.toArray()});return result;};let e=await W5(n);';const original=html.toString();if(original.split(start).length!==2)throw Error('Enemy instrumentation anchor changed');servedHtml=Buffer.from(original.replace(start,instrumented));}
 const browser=await chromium.launch({executablePath:'/usr/bin/google-chrome',headless:true,args:['--no-sandbox','--use-angle=gl','--ignore-gpu-blocklist']});
 try{
 const page=await browser.newPage({viewport:{width:1280,height:720}});const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='fonts.googleapis.com'?r.fulfill({status:200,contentType:'text/css',body:fontCss}):new URL(r.request().url()).pathname==='/saltline.original.html'?r.fulfill({status:200,contentType:'text/html',body:servedHtml}):r.abort());
 await page.goto('http://saltline-reference.invalid/saltline.original.html?q='+quality+'&shot=1&noaudio=1&step=1&dt=0.016666666666666666&cam='+camera+'&fov=74'+(showcase?'&show='+showcase:'')+(backdropPart?'&bshow='+backdropPart:'')+(showcase==='enemies'?'&eshow='+enemyPart+'&efreeze=1':''));await page.waitForFunction(()=>window.__ready&&window.__step===0,{timeout:180000});
 if(process.argv.includes('--labels-only')){
  if(showcase!=='backdrop')throw Error('Label audit requires backdrop showcase');
  const labels=await page.evaluate(()=>{
   const rows=[];const g=__G,gl=g.renderer.getContext(),previous=gl.getParameter(gl.FRAMEBUFFER_BINDING),fbo=gl.createFramebuffer();
   const encode=bytes=>{let text='';for(let i=0;i<bytes.length;i+=32768)text+=String.fromCharCode(...bytes.subarray(i,i+32768));return btoa(text);};
   try{g.scene.traverse(node=>{
    const materials=Array.isArray(node.material)?node.material:[node.material];
    for(const material of materials)if(material?.name==='label'){
     const maps={};for(const key of ['map','roughnessMap','normalMap','alphaMap']){
      const texture=material[key];if(!texture)continue;
      const image=texture.image,canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;
      const context=canvas.getContext('2d');context.drawImage(image,0,0);
      const pixels=context.getImageData(0,0,canvas.width,canvas.height).data;let text='';
      for(let i=0;i<pixels.length;i+=32768)text+=String.fromCharCode(...pixels.subarray(i,i+32768));
      const levels=[];g.renderer.initTexture(texture);let width=image.width,height=image.height,level=0;
      while(true){gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,g.renderer.properties.get(texture).__webglTexture,level);if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)throw Error('Label mip framebuffer');const bytes=new Uint8Array(width*height*4);gl.readPixels(0,0,width,height,gl.RGBA,gl.UNSIGNED_BYTE,bytes);if(gl.getError()!==gl.NO_ERROR)throw Error('Label mip readback');levels.push({width,height,base64:encode(bytes)});if(width===1&&height===1)break;width=Math.max(1,width>>1);height=Math.max(1,height>>1);level++;}
      maps[key]={width:canvas.width,height:canvas.height,pixels:btoa(text),png:canvas.toDataURL('image/png').split(',')[1],levels,wrapS:texture.wrapS,wrapT:texture.wrapT,repeat:texture.repeat.toArray(),offset:texture.offset.toArray(),flipY:texture.flipY,colorSpace:texture.colorSpace};
     }
     const a=node.geometry.attributes.position.array;rows.push({maps,position:encode(new Uint8Array(a.buffer,a.byteOffset,a.byteLength))});
    }
   });}finally{gl.bindFramebuffer(gl.FRAMEBUFFER,previous);gl.deleteFramebuffer(fbo);}return rows;
  });
  if(!labels.length)throw Error('No source labels found');
  for(const [index,row] of labels.entries()){
   row.position_sha256=crypto.createHash('sha256').update(Buffer.from(row.position,'base64')).digest('hex');delete row.position;
   for(const [key,map] of Object.entries(row.maps)){
    map.sha256=crypto.createHash('sha256').update(Buffer.from(map.pixels,'base64')).digest('hex');map.file='backdrop-labels-'+(backdropPart||'all')+'-'+index+'-'+key+'-source.png';fs.writeFileSync(path.join(out,map.file),Buffer.from(map.png,'base64'));
    const bytes=Buffer.concat(map.levels.map(level=>Buffer.from(level.base64,'base64')));map.mip_file=map.file.replace('.png','.source-miprgba');map.mip_sha256=crypto.createHash('sha256').update(bytes).digest('hex');fs.writeFileSync(path.join(out,map.mip_file),bytes);for(const level of map.levels)delete level.base64;
    delete map.pixels;delete map.png;
   }
  }
  if(errors.length)throw Error(errors.join('\n'));
  fs.writeFileSync(path.join(out,'backdrop-labels-'+(backdropPart||'all')+'-source.json'),JSON.stringify({source_sha256:crypto.createHash('sha256').update(html).digest('hex'),labels,errors,scope:'Actual original backdrop label CanvasTexture RGBA8 pixels and sampler transforms; local original font faces, no source HTML edits.'},null,2)+'\n');
  console.log(JSON.stringify({labels:labels.length,part:backdropPart||'all'}));return;
 }
 const captureHdr=process.argv.includes('--hdr');
 if(captureHdr)await page.evaluate(()=>{const g=__G,render=g.renderer.render.bind(g.renderer);g.renderer.render=function(scene,camera){const result=render(scene,camera);const target=this.getRenderTarget();if(scene===g.scene&&camera===g.camera&&target?.texture.type===g.THREE.HalfFloatType){const raw=new Uint16Array(target.width*target.height*4);this.readRenderTargetPixels(target,0,0,target.width,target.height,raw);let text='';const bytes=new Uint8Array(raw.buffer);for(let i=0;i<bytes.length;i+=32768)text+=String.fromCharCode(...bytes.subarray(i,i+32768));window.__pairedHdr={width:target.width,height:target.height,base64:btoa(text)};}return result;};});
 const surface=process.argv.find(x=>x.startsWith('--surface='))?.slice(10)||'';
 if(surface){if(!['normal','roughness','direct-specular','indirect-specular'].includes(surface))throw Error('Invalid surface diagnostic');await page.evaluate(mode=>{const seen=new Set();__G.scene.traverse(n=>{const m=n.material;if(!m?.isMeshStandardMaterial||m.name!=='corrugated_roof'||seen.has(m))return;seen.add(m);const old=m.onBeforeCompile,key=m.customProgramCacheKey.bind(m);m.customProgramCacheKey=()=>key()+':main-diagnostic-'+mode;m.onBeforeCompile=function(shader,renderer){old.call(this,shader,renderer);const value=mode==='normal'?'normalize(normal)*.5+.5':mode==='roughness'?'vec3(roughnessFactor)':mode==='direct-specular'?'reflectedLight.directSpecular':'reflectedLight.indirectSpecular';shader.fragmentShader=shader.fragmentShader.replace('#include <opaque_fragment>','gl_FragColor=vec4('+value+',1.);return;');};m.needsUpdate=true;});},surface);}
 const noPoints=process.argv.includes('--no-points'),noSun=process.argv.includes('--no-sun');
 const data=await page.evaluate(({noPoints,noSun})=>{const g=__G,T=g.THREE;const lights=[];g.scene.updateMatrixWorld(true);g.scene.traverse(n=>{if(n.isLight)lights.push({name:n.name,type:n.type,visible:n.visible,intensity:n.intensity,color:n.color.toArray(),position:n.getWorldPosition(new T.Vector3()).toArray(),distance:n.distance,decay:n.decay,layers:n.layers.mask});if(noPoints&&n.isPointLight)n.visible=false;});if(noSun)g.render.sun.visible=false;g.weapon.setVisible(false);g.render.autoExposure=false;g.render.exposure=1;g.render.fade=0;g.render.motionBlur=false;for(let i=0;i<12;i++)g.render.frame(0);const rays=[];const nodes=[];g.scene.traverse(n=>nodes.push(n));for(const [x,y] of [[856,298],[850,300],[860,300]]){const ray=new T.Raycaster();ray.setFromCamera(new T.Vector2(x/1280*2-1,1-y/720*2),g.camera);const hits=ray.intersectObjects(g.scene.children,true).filter(hit=>{for(let n=hit.object;n;n=n.parent)if(!n.visible)return false;return true;});rays.push({pixel:[x,y],hits:hits.slice(0,5).map(hit=>({ordinal:nodes.indexOf(hit.object),name:hit.object.name,material:Array.isArray(hit.object.material)?hit.object.material.map(m=>m.name):hit.object.material?.name,distance:hit.distance,point:hit.point.toArray(),uv:hit.uv?.toArray()}))});}const gl=g.renderer.getContext(),debug=gl.getExtension('WEBGL_debug_renderer_info');return {lights,no_points:noPoints,no_sun:noSun,rays,time:g.time,camera:{position:g.camera.position.toArray(),quaternion:g.camera.quaternion.toArray(),fov:g.camera.fov,near:g.camera.near,far:g.camera.far},quality:g.quality,view_fill:g.render.viewFill,fade:g.render.fade,exposure:g.render.exposure,backend:gl.getParameter(debug.UNMASKED_RENDERER_WEBGL)};},{noPoints,noSun});
 if(showcase==='enemies')data.enemies=await page.evaluate(()=>{
  const e=__G.enemies,primitive=s=>Object.fromEntries(Object.entries(s).filter(([k,v])=>typeof v==='number'||typeof v==='boolean'||typeof v==='string'||v?.isVector3).map(([k,v])=>[k,v?.isVector3?v.toArray():v]));
  return {nav_tape:window.__enemyNavTape||[],time:e.debug.ctx.t,player:primitive(__G.player),actors:e.list.map(a=>({state:primitive(a),group:a.rig.group.matrix.toArray(),bones:Object.fromEntries(Object.entries(a.rig.bones).map(([key,b])=>[key,{matrix:b.matrix.toArray(),world:b.matrixWorld.toArray()}]))})),scope:'Original frozen showcase after the exact KD prewarm; primitive actor state and local/world bone matrices.'};
 });
 if(['level','backdrop'].includes(showcase)){
  const inventoryBuffers=new Map();
  await page.exposeFunction('_saltlineBufferHash',text=>{const buffer=Buffer.from(text,'base64'),digest=crypto.createHash('sha256').update(buffer).digest('hex');inventoryBuffers.set(digest,buffer);return digest;});
  const inventory=await page.evaluate(async(showcase)=>{
   if(__G.showcase!==showcase)throw Error('Unexpected original showcase');const group=__G.scene.children.find(n=>n.name===showcase);if(!group)throw Error('Original showcase root missing');
   async function hash(array){let text='';const bytes=new Uint8Array(array.buffer,array.byteOffset,array.byteLength);for(let i=0;i<bytes.length;i+=32768)text+=String.fromCharCode(...bytes.subarray(i,i+32768));return await window._saltlineBufferHash(btoa(text));}
   const geometries=new Map(),objects=[];group.updateMatrixWorld(true);group.traverse(n=>{if(n.isMesh){geometries.set(n.geometry.uuid,n.geometry);objects.push(n);}});
   const signatures={};for(const [id,g]of geometries){const attributes={};for(const name of Object.keys(g.attributes).sort()){const a=g.attributes[name];let array=a.array;if(a.isInterleavedBufferAttribute){array=new Float32Array(a.count*a.itemSize);for(let i=0;i<array.length;i++)array[i]=a.getComponent(Math.floor(i/a.itemSize),i%a.itemSize);}attributes[name]={dtype:array.constructor.name,itemSize:a.itemSize,count:a.count,normalized:a.normalized,sha256:await hash(array)};}signatures[id]={attributes,index:g.index?{dtype:g.index.array.constructor.name,count:g.index.count,sha256:await hash(g.index.array)}:null,groups:g.groups};}
   const nodes=[];for(const n of objects){const materials=(Array.isArray(n.material)?n.material:[n.material]);const row={name:n.name,geometry:signatures[n.geometry.uuid],materials:materials.map(m=>({name:m.name,env_map:m.envMap!==null,env_intensity:m.envMapIntensity})),matrix:n.matrixWorld.toArray(),visible:n.visible,castShadow:n.castShadow,receiveShadow:n.receiveShadow};if(n.isInstancedMesh){row.instance_matrix_sha256=await hash(n.instanceMatrix.array);if(n.instanceColor)row.instance_color_sha256=await hash(n.instanceColor.array);}nodes.push(row);}
   return {nodes,geometries:geometries.size};
  },showcase);
  if(showcase==='backdrop'){
   const prefix='showcase/backdrop-'+(backdropPart||'all'),geometryDir=path.join(root,'saltline-godot/assets/export',prefix);fs.mkdirSync(geometryDir,{recursive:true});
   for(const [index,row]of inventory.nodes.entries())if(row.geometry.attributes.blink||row.materials.every(m=>m.name==='label')){
    const geometry={id:'backdrop-'+(backdropPart||'all')+'-mesh-'+index,attributes:{},groups:[],index:null};
    for(const [name,info]of Object.entries(row.geometry.attributes)){const file=name+'-'+info.sha256+'.bin';fs.writeFileSync(path.join(geometryDir,file),inventoryBuffers.get(info.sha256));geometry.attributes[name]={...info,file:prefix+'/'+file};}
    const sourceIndex=row.geometry.index;const count=sourceIndex?sourceIndex.count:row.geometry.attributes.position.count;if(count%3)throw Error('Incomplete original backdrop triangles');const rawIndex=sourceIndex?inventoryBuffers.get(sourceIndex.sha256):null;const readIndex=sourceIndex?.dtype==='Uint16Array'?i=>rawIndex.readUInt16LE(i*2):sourceIndex?.dtype==='Uint32Array'?i=>rawIndex.readUInt32LE(i*4):sourceIndex?null:i=>i;if(!readIndex)throw Error('Unsupported original index type');const indices=Uint32Array.from({length:count},(_,i)=>readIndex(i));for(let i=0;i<count;i+=3)[indices[i+1],indices[i+2]]=[indices[i+2],indices[i+1]];const file='indices-'+index+'.bin';fs.writeFileSync(path.join(geometryDir,file),Buffer.from(indices.buffer));geometry.godot_index='res://assets/export/'+prefix+'/'+file;row.exported_blink_geometry=geometry;
   }
  }
  inventory.source_sha256=crypto.createHash('sha256').update(html).digest('hex');inventory.scope='Actual original '+showcase+' geometry attributes/index/world matrices/material environment flags; common floor/global lights separately captured. Backdrop blink buffers also retained for exact selected-lamp reconstruction.';fs.writeFileSync(path.join(out,showcase+(backdropPart?'-'+backdropPart:'')+'-showcase-source-inventory.json'),JSON.stringify(inventory,null,2));
 }
 if(captureHdr){const hdr=await page.evaluate(()=>window.__pairedHdr);if(!hdr)throw Error('No world HDR target captured');hdr.file='main-paired-'+tag+'-source.world.rgba16f';fs.writeFileSync(path.join(out,hdr.file),Buffer.from(hdr.base64,'base64'));delete hdr.base64;hdr.row_order='bottom-to-top';data.hdr=hdr;}
 await page.addStyleTag({content:'#ui,#boot{display:none!important}'});await page.screenshot({path:path.join(out,'main-paired-'+tag+'-source.png')});data.surface_diagnostic=surface;data.instrumented_html_sha256=crypto.createHash('sha256').update(servedHtml).digest('hex');data.enemy_nav_instrumented=captureEnemyNav;data.source_sha256=crypto.createHash('sha256').update(html).digest('hex');data.errors=errors;data.scope='Actual original Main fixed camera and source time, manual exposure1, weapon/HUD hidden,12 zero-dt renders to warm render passes. Diagnostic paired scene, not normal gameplay.';fs.writeFileSync(path.join(out,'main-paired-'+tag+'-source.json'),JSON.stringify(data,null,2));console.log(JSON.stringify(data));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
