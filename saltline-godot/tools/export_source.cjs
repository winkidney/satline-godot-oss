async(page)=>{
 await page.waitForFunction(()=>window.__ready&&window.__step===0);
 return await page.evaluate(async()=>{
  const g=__G,T=g.THREE,endpoint='http://127.0.0.1:8794/';
  async function save(path,json){const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path,json})});if(!r.ok)throw Error(await r.text());}
  function base64(bytes){let s='';for(let i=0;i<bytes.length;i+=8192)s+=String.fromCharCode(...bytes.subarray(i,i+8192));return btoa(s);}
  async function binary(path,array){const r=await fetch(endpoint,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({path,base64:base64(new Uint8Array(array.buffer,array.byteOffset,array.byteLength))})});if(!r.ok)throw Error(await r.text());}
  function plain(x,depth=0,seen=new Set()){
   if(typeof x==='number')return Number.isFinite(x)?x:{$number:String(x)};
   if(x===null||typeof x==='string'||typeof x==='boolean')return x;
   if(typeof x==='function'||x===undefined||depth>7)return undefined;
   if(x.isObject3D)return {$node:x.uuid};if(x.isMaterial)return {$material:x.uuid};if(x.isTexture)return {$texture:x.uuid};
   if(x.isVector2||x.isVector3||x.isVector4||x.isQuaternion||x.isColor||x.isMatrix4)return x.toArray();
   if(ArrayBuffer.isView(x))return Array.from(x);
   if(seen.has(x))return {$cycle:true};seen.add(x);
   const result=Array.isArray(x)?x.map(v=>plain(v,depth+1,seen)):Object.fromEntries(Object.entries(x).map(([k,v])=>[k,plain(v,depth+1,seen)]).filter(([k,v])=>v!==undefined));seen.delete(x);return result;
  }
  const geometries=new Map(),materials=new Map(),textures=new Map(),nodes=[];
  function collectTexture(v){if(v?.isTexture)textures.set(v.uuid,v);}
  // Include pooled/invisible assets, not only currently visible draw calls.
  g.scene.updateMatrixWorld(true);
  g.scene.traverse(o=>{
   const n={id:o.uuid,parent:o.parent?.uuid||null,name:o.name,type:o.type,visible:o.visible,layers:o.layers.mask,
    matrix:o.matrix.toArray(),matrixWorld:o.matrixWorld.toArray(),castShadow:!!o.castShadow,receiveShadow:!!o.receiveShadow,userData:plain(o.userData)};
   if(o.geometry){geometries.set(o.geometry.uuid,o.geometry);n.geometry=o.geometry.uuid;}
   if(o.material){const mm=Array.isArray(o.material)?o.material:[o.material];n.materials=mm.map(m=>m.uuid);mm.forEach(m=>materials.set(m.uuid,m));}
   if(o.isInstancedMesh){n.instanceCount=o.count;n.instanceCapacity=o.instanceMatrix.count;n.instanceMatrix=Array.from(o.instanceMatrix.array);if(o.instanceColor)n.instanceColor=Array.from(o.instanceColor.array);}
   if(o.isSkinnedMesh)n.skin={bones:o.skeleton.bones.map(b=>b.uuid),boneInverses:o.skeleton.boneInverses.map(m=>m.toArray()),bindMatrix:o.bindMatrix.toArray(),bindMatrixInverse:o.bindMatrixInverse.toArray(),bindMode:o.bindMode};
   if(o.isLight)n.light={color:o.color.toArray(),intensity:o.intensity,distance:o.distance,decay:o.decay,angle:o.angle,penumbra:o.penumbra};
   if(o.isCamera)n.camera={fov:o.fov,near:o.near,far:o.far,aspect:o.aspect};
   nodes.push(n);
  });
  const patches=new Map();
  for(const m of materials.values()){
   const patch={uniforms:{},vertexShader:T.ShaderLib.standard.vertexShader,fragmentShader:T.ShaderLib.standard.fragmentShader};
   m.onBeforeCompile(patch,g.renderer);patches.set(m.uuid,patch);
   for(const u of Object.values(patch.uniforms))collectTexture(u.value);
   for(const v of Object.values(m))collectTexture(v);
   for(const u of Object.values(m.uniforms||{}))collectTexture(u.value);
   for(const u of Object.values(m.userData?.sl||{}))collectTexture(u.value);
  }
  const geometryInfo=[];
  for(const [id,geo] of geometries){
   const attributes={};
   for(const [name,a] of Object.entries(geo.attributes)){
    let array=a.array;
    if(a.isInterleavedBufferAttribute){array=new Float32Array(a.count*a.itemSize);for(let i=0;i<a.count;i++)for(let c=0;c<a.itemSize;c++)array[i*a.itemSize+c]=a.getComponent(i,c);}
    const file=`geometry/${id}-${name}.bin`;await binary(file,array);attributes[name]={file,dtype:array.constructor.name,itemSize:a.itemSize,count:a.count,normalized:a.normalized};
   }
   let index=null;if(geo.index){const file=`geometry/${id}-index.bin`;await binary(file,geo.index.array);index={file,dtype:geo.index.array.constructor.name,count:geo.index.count};}
   const item={id,name:geo.name,type:geo.type,attributes,index,groups:geo.groups,drawRange:plain(geo.drawRange),morphTargetsRelative:geo.morphTargetsRelative,morphAttributes:{}};
   for(const [name,aa] of Object.entries(geo.morphAttributes)){
    item.morphAttributes[name]=[];for(let j=0;j<aa.length;j++){const a=aa[j],file=`geometry/${id}-morph-${name}-${j}.bin`;await binary(file,a.array);item.morphAttributes[name].push({file,dtype:a.array.constructor.name,itemSize:a.itemSize,count:a.count});}
   }
   geometryInfo.push(item);
  }
  // Keep source skin data AND a posed review mesh for the initial renderer.
  let posed=0;
  for(const o of (()=>{const a=[];g.scene.traverse(o=>{if(o.isSkinnedMesh)a.push(o)});return a})()){
   const pos=o.geometry.attributes.position,arr=new Float32Array(pos.count*3),v=new T.Vector3();
   for(let i=0;i<pos.count;i++){v.fromBufferAttribute(pos,i);o.applyBoneTransform(i,v);v.toArray(arr,i*3);}
   const file=`geometry/posed-${o.uuid}.bin`;await binary(file,arr);nodes.find(n=>n.id===o.uuid).posedPositions={file,dtype:'Float32Array',itemSize:3,count:pos.count};posed++;
  }
  const materialInfo=[];
  for(const [id,m] of materials){
   const props={};for(const k of ['color','emissive','emissiveIntensity','roughness','metalness','opacity','transparent','alphaTest','side','depthWrite','depthTest','blending','vertexColors','normalScale','envMapIntensity','map','normalMap','roughnessMap','metalnessMap','aoMap','alphaMap','emissiveMap','bumpMap','bumpScale','polygonOffset','polygonOffsetFactor','polygonOffsetUnits','toneMapped','defines'])props[k]=plain(m[k]);
   materialInfo.push({id,name:m.name,type:m.type,props,uniforms:plain(m.uniforms),userData:plain(m.userData),patch:plain(patches.get(id)),onBeforeCompile:String(m.onBeforeCompile),vertexShader:m.vertexShader,fragmentShader:m.fragmentShader});
  }
  collectTexture(g.scene.environment);
  const textureInfo=[];
  const rt=new T.WebGLRenderTarget(4,4,{depthBuffer:false,colorSpace:T.NoColorSpace});
  const quad=new T.Mesh(new T.PlaneGeometry(2,2),null),scene=new T.Scene(),camera=new T.OrthographicCamera(-1,1,1,-1,0,1);scene.add(quad);
  const sm=new T.ShaderMaterial({uniforms:{tex:{value:null},encode:{value:0}},vertexShader:'varying vec2 v;void main(){v=uv;gl_Position=vec4(position.xy,0.,1.);}',fragmentShader:'uniform sampler2D tex;uniform float encode;varying vec2 v;vec3 srgb(vec3 c){return mix(12.92*c,1.055*pow(max(c,vec3(0.)),vec3(1./2.4))-.055,step(vec3(.0031308),c));}void main(){vec4 c=texture2D(tex,v);if(encode>.5)c.rgb=srgb(c.rgb);gl_FragColor=c;}',depthTest:false,depthWrite:false,toneMapped:false});quad.material=sm;
  const previous=g.renderer.getRenderTarget(),ac=g.renderer.autoClear;g.renderer.autoClear=true;
  for(const [id,tex] of textures){
   const img=tex.image;let width=img?.width||img?.videoWidth||1,height=img?.height||img?.videoHeight||1;
   const item={id,name:tex.name,type:tex.type,format:tex.format,colorSpace:tex.colorSpace,wrapS:tex.wrapS,wrapT:tex.wrapT,magFilter:tex.magFilter,minFilter:tex.minFilter,flipY:tex.flipY,repeat:tex.repeat.toArray(),offset:tex.offset.toArray(),rotation:tex.rotation,channel:tex.channel,width,height,isCube:!!tex.isCubeTexture};
   if(tex.isCubeTexture||tex.isData3DTexture||tex.isDataArrayTexture){item.pendingReason='cube/3D/array requires dedicated export';textureInfo.push(item);continue;}
   if(!img){item.pendingReason='no image allocation';textureInfo.push(item);continue;}
   rt.setSize(width,height);sm.uniforms.tex.value=tex;sm.uniforms.encode.value=tex.colorSpace===T.SRGBColorSpace?1:0;
   g.renderer.setRenderTarget(rt);g.renderer.render(scene,camera);
   const bytes=new Uint8Array(width*height*4);g.renderer.readRenderTargetPixels(rt,0,0,width,height,bytes);
   // Raw readback is bottom row first. Receiver converts to PNG without changing channels.
   const file=`textures/${id}.rgba`;await binary(file,bytes);item.file=file;item.channels=4;item.rowOrder='bottom-to-top';item.encoding=tex.colorSpace===T.SRGBColorSpace?'srgb':'linear-data';textureInfo.push(item);
  }
  const skySource=g.render.sky.material;
  const skyFloat=new T.WebGLRenderTarget(1024,512,{type:T.FloatType,depthBuffer:false,colorSpace:T.NoColorSpace});
  const skyShader=new T.ShaderMaterial({uniforms:T.UniformsUtils.clone(skySource.uniforms),vertexShader:'varying vec2 expUv;void main(){expUv=uv;gl_Position=vec4(position.xy,0.,1.);}',fragmentShader:skySource.fragmentShader.replace('varying vec3 vDir;','varying vec2 expUv;').replace('void main() {','void main() { vec3 vDir=vec3(sin(expUv.x*6.28318530718)*sin(expUv.y*3.14159265359),-cos(expUv.y*3.14159265359),cos(expUv.x*6.28318530718)*sin(expUv.y*3.14159265359));'),depthTest:false,depthWrite:false,toneMapped:false});
  // Source main uses compact spacing in some versions.
  if(!skyShader.fragmentShader.includes('vec3 vDir='))skyShader.fragmentShader=skyShader.fragmentShader.replace('void main(){','void main(){vec3 vDir=vec3(sin(expUv.x*6.28318530718)*sin(expUv.y*3.14159265359),-cos(expUv.y*3.14159265359),cos(expUv.x*6.28318530718)*sin(expUv.y*3.14159265359));');
  quad.material=skyShader;
  for(const env of [0,1]){skyShader.uniforms.uEnv.value=env;g.renderer.setRenderTarget(skyFloat);g.renderer.render(scene,camera);const data=new Float32Array(1024*512*4);g.renderer.readRenderTargetPixels(skyFloat,0,0,1024,512,data);await binary(`environment/sky-${env}.rgba32f`,data);}
  skyFloat.dispose();skyShader.dispose();
  g.renderer.setRenderTarget(previous);g.renderer.autoClear=ac;rt.dispose();sm.dispose();quad.geometry.dispose();
  const modules={};for(const name of ['level','backdrop','weapon','enemies','player','game','explosives'])modules[name]=plain(g[name]);
  const data={schema:1,source:'Saltline current active script',sourceHash:'b83fc642f3696c21a9efbf36c29bd9c0c7e1e9725fe215d4a043fa4a10bccbeb',coordinateSystem:'RH Y-up, camera -Z; Three CCW triangles',seed:g.params.seed||4207,quality:plain(g.quality),time:plain(g.time),nodes,geometries:geometryInfo,materials:materialInfo,textures:textureInfo,modules,physics:{boxes:plain(g.physics.boxes),bounds:plain(g.physics.bounds)},environment:{width:1024,height:512,channels:4,type:'Float32Array',rowOrder:'bottom-to-top',background:'environment/sky-0.rgba32f',lighting:'environment/sky-1.rgba32f'},errors:window.__errors};
  await save('scenes/main.json',data);
  const summary={nodes:nodes.length,geometries:geometryInfo.length,materials:materialInfo.length,textures:textureInfo.length,posed,unsupportedTextures:textureInfo.filter(t=>t.pendingReason),errors:window.__errors};await save('export-summary.json',summary);return summary;
 });
}
