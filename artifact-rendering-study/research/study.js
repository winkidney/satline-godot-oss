/* Diagnostic API for the research copy only. Never included by the original HTML. */
(() => {
  let baseline, quality, gpu = null;
  const G = () => window.__G;
  function init() {
    baseline ||= {...G().render.tune}; quality ||= {...G().quality};
  }
  function reset() {
    init(); Object.assign(G().render.tune, baseline);
    Object.assign(G().quality, quality);
    G().render.autoExposure = false;
    G().render.exposure = 0.7;
    Object.assign(G().render.post, {damage:0,lowHealth:0,ads:0,flash:0,fade:0,saturation:1});
    G().render.tune.grain = 0;
  }
  function frame(count = 3) {
    for(let i=0;i<count;i++) G().render.frame(1/60);
  }
  function view(pos, target, fov=62) {
    const c=G().camera;c.position.fromArray(pos);c.lookAt(...target);c.fov=fov;
    c.updateProjectionMatrix();c.updateMatrixWorld(true);
  }
  function info() {
    const g=G().renderer.getContext(), e=g.getExtension('WEBGL_debug_renderer_info');
    return {url:location.href,ready:window.__ready,fatal:window.__fatal,errors:window.__errors,
      gpu:e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER),
      webgl:g.getParameter(g.VERSION),extensions:g.getSupportedExtensions(),
      quality:{...G().quality},stats:window.__stats(),tune:{...G().render.tune},
      camera:{position:G().camera.position.toArray(),matrix:G().camera.matrixWorld.toArray(),fov:G().camera.fov},
      time:{...G().time},materials:G().mats.stats(),autoExposure:G().render.autoExposure};
  }
  function texture(target, {attachment=0,mode='raw',channel=null,scale=1,binary=false}={}) {
    const T=G().THREE, w=target.width,h=target.height;
    const tex=target.textures?.[attachment]||target.texture;
    const channels=tex.format===T.RedFormat?1:tex.format===T.RGFormat?2:4;
    const data=tex.type===T.HalfFloatType?new Uint16Array(w*h*channels):tex.type===T.FloatType?new Float32Array(w*h*channels):new Uint8Array(w*h*channels);
    G().renderer.readRenderTargetPixels(target,0,0,w,h,data,undefined,attachment);
    const get=i=>tex.type===T.HalfFloatType?T.DataUtils.fromHalfFloat(data[i]):tex.type===T.FloatType?data[i]:data[i]/255;
    if(binary){
      const bytes=new Uint8Array(data.buffer);let str='';
      for(let i=0;i<bytes.length;i+=8192)str+=String.fromCharCode(...bytes.subarray(i,i+8192));
      return {width:w,height:h,type:tex.type,format:tex.format,channels,dtype:data.constructor.name,
        endian:new Uint8Array(new Uint16Array([1]).buffer)[0]===1?'little':'big',base64:btoa(str)};
    }
    const out=new Uint8ClampedArray(w*h*4);
    for(let y=0;y<h;y++) for(let x=0;x<w;x++) {
      const src=(y*w+x)*channels,dst=((h-1-y)*w+x)*4;
      for(let c=0;c<3;c++) {
        let v=channel==='height'?get(src)+get(src+1)/255:get(src+(channel===null?Math.min(c,channels-1):channel));
        v*=scale;if(mode==='hdr')v=Math.pow(Math.max(0,v)/(1+Math.max(0,v)),1/2.2);
        out[dst+c]=Math.round(Math.max(0,Math.min(1,v))*255);
      } out[dst+3]=255;
    }
    const cv=document.createElement('canvas');cv.width=w;cv.height=h;
    cv.getContext('2d').putImageData(new ImageData(out,w,h),0,0);
    return {width:w,height:h,type:tex.type,format:tex.format,channels,mode,channel,scale,png:cv.toDataURL('image/png')};
  }
  function timer(enabled) {
    if(!enabled){window.__studyGpu=null;return;}
    const gl=G().renderer.getContext(), ext=gl.getExtension('EXT_disjoint_timer_query_webgl2');
    if(!ext)return false;
    gpu={gl,ext,pending:[],results:[],active:null,begin(name,rt){
      if(this.pending.length>512)return;
      const q=gl.createQuery();gl.beginQuery(ext.TIME_ELAPSED_EXT,q);
      this.active={q,name,size:rt?[rt.width,rt.height]:G().render.resolution.toArray()};
    },end(){if(this.active){gl.endQuery(ext.TIME_ELAPSED_EXT);this.pending.push(this.active);this.active=null;}},poll(){
      const disjoint=gl.getParameter(ext.GPU_DISJOINT_EXT);
      if(disjoint){this.results.push({invalid:true,reason:"GPU_DISJOINT",discarded:this.pending.length});for(const item of this.pending)gl.deleteQuery(item.q);this.pending=[];return {pending:0,results:this.results};}
      this.pending=this.pending.filter(item=>{
        if(!gl.getQueryParameter(item.q,gl.QUERY_RESULT_AVAILABLE))return true;
        const ns=gl.getQueryParameter(item.q,gl.QUERY_RESULT);
        this.results.push({name:item.name,size:item.size,ms:ns/1e6,disjoint});gl.deleteQuery(item.q);return false;
      });return {pending:this.pending.length,results:this.results};
    }};window.__studyGpu=gpu;return true;
  }
  window.study={reset,frame,view,info,texture,timer,gpu:()=>gpu?.poll(),
    buffers:()=>Object.fromEntries(Object.entries(G().researchPost.rt).map(([k,v])=>[k,Array.isArray(v)?v.map(x=>[x.width,x.height]):v?[v.width,v.height]:null]))};
})();
