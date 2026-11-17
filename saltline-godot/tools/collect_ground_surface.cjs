async(page)=>{await page.waitForFunction(()=>window.__ready||window.__fatal,{timeout:120000});return await page.evaluate(async()=>{
 const g=__G,rects=window.__groundMetalRects.map(r=>Array.from(r)),points=[];
 for(let x=-42;x<=42;x+=.75)for(let z=-34;z<=34;z+=.75)points.push([x,z]);
 for(const r of rects)for(const x of [r[0]-1e-7,r[0],r[0]+1e-7,(r[0]+r[2])/2,r[2]-1e-7,r[2],r[2]+1e-7])for(const z of [r[1]-1e-7,r[1],r[1]+1e-7,(r[1]+r[3])/2,r[3]-1e-7,r[3],r[3]+1e-7])points.push([x,z]);
 const rows=points.map(([x,z])=>({x,z,metal:window.__groundMetalAt(x,z),surface:g.level.groundSurfaceAt(x,z)}));
 const bytes=await(await fetch('/output/playwright/ground-instrumented.js')).arrayBuffer(),sha=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),v=>v.toString(16).padStart(2,'0')).join(''),gl=g.renderer.getContext(),debug=gl.getExtension('WEBGL_debug_renderer_info');
 const data={ready:window.__ready,fatal:window.__fatal,errors:window.__errors,params:g.params,time:g.time,quality:g.quality,instrumented_response_sha256:sha,rects,rows,player_start:{pos:g.level.playerStart.pos.toArray(),yaw:g.level.playerStart.yaw},backend:gl.getParameter(debug.UNMASKED_RENDERER_WEBGL),scope:'Original uw metalRects and original uw.k/level.groundSurfaceAt from observed completed high-quality default-seed scene; no simulation methods replaced.'};
 return btoa(JSON.stringify(data));
 });}
