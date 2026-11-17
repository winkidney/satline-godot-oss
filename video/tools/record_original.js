async page => {
  const spec=__CAPTURE_SPEC__;
  await page.evaluate(({pos,yaw,pitch})=>{
    const game=window.__G.game;if(game.state!=='playing')game.start({skipIntro:true});
    const p=window.__G.player;p.invulnerable=true;p.pos.set(...pos);p.lastSafe.copy(p.pos);p.vel.set(0,0,0);p.yaw=yaw;p.pitch=pitch;
  },spec);
  await page.waitForTimeout(2500);
  await page.evaluate(()=>{
    const stream=document.querySelector('canvas').captureStream(60);
    stream.addTrack(window.__G.audio.ctx.__recordDestination.stream.getAudioTracks()[0].clone());
    const recorder=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp8,opus',videoBitsPerSecond:16000000,audioBitsPerSecond:192000});
    const chunks=[],samples=[];recorder.ondataavailable=e=>{if(e.data.size)chunks.push(e.data)};
    const started=performance.now(),frames=window.__frames;
    const timer=setInterval(()=>samples.push({seconds:(performance.now()-started)/1000,frames:window.__frames-frames,state:window.__G.game.state}),1000);
    recorder.start(1000);window.__filmCapture={recorder,chunks,stream,started,frames,timer,samples};
  });
  const started=Date.now();
  for(const action of spec.actions){
    const wait=action.at*1000-(Date.now()-started);if(wait>0)await page.waitForTimeout(wait);
    if(action.kind==='down')await page.keyboard.down(action.key);
    if(action.kind==='up')await page.keyboard.up(action.key);
    if(action.kind==='press')await page.keyboard.press(action.key);
    if(action.kind==='fire-down')await page.mouse.down();
    if(action.kind==='fire-up')await page.mouse.up();
    if(action.kind==='warp')await page.evaluate(({pos,yaw,pitch})=>{const p=window.__G.player;p.pos.set(...pos);p.lastSafe.copy(p.pos);p.vel.set(0,0,0);p.yaw=yaw;p.pitch=pitch;},action);
  }
  const remaining=spec.duration*1000-(Date.now()-started);if(remaining>0)await page.waitForTimeout(remaining);
  const stats=await page.evaluate(()=>{const c=window.__filmCapture;clearInterval(c.timer);return {seconds:(performance.now()-c.started)/1000,frames:window.__frames-c.frames,samples:c.samples,stats:window.__stats(),fatal:window.__fatal,errors:window.__errors}});
  const [download]=await Promise.all([page.waitForEvent('download'),page.evaluate(async()=>{
    const c=window.__filmCapture;await new Promise(resolve=>{c.recorder.onstop=resolve;c.recorder.stop()});
    const a=document.createElement('a');a.href=URL.createObjectURL(new Blob(c.chunks,{type:'video/webm'}));a.download='saltline-original.webm';a.click();c.stream.getTracks().forEach(track=>track.stop());
  })]);
  await download.saveAs(spec.output);
  return {name:spec.name,...stats};
}
