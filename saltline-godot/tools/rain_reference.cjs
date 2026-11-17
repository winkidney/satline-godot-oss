const fs=require('fs'),crypto=require('node:crypto'),runtime=process.argv.includes('--runtime'),canonical=process.argv.includes('--canonical')||runtime,text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8'),level=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json')).modules.level;
const begin=text.indexOf('      update(w) {',text.indexOf('  function Gw('));let brace=text.indexOf('{',begin),depth=1,end=brace+1;while(depth){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++}
class Vec{constructor(x=0,y=0,z=0,w=0){this.set(x,y,z,w)}set(x,y,z,w){Object.assign(this,{x,y,z,w});return this}copy(v){Object.assign(this,v);return this}toJSON(){return [this.x,this.y,...(this.z===undefined?[]:[this.z]),...(this.w===undefined?[]:[this.w])]}}
let calls=0,seed=canonical?1278876144:1337;let rngAt=text.indexOf('function su(n = 1337)'),raw=eval('('+text.slice(rngAt,text.indexOf('\n  var Hn =',rngAt)).trim()+')')(seed),t=()=>{calls++;return raw()};if(canonical)for(let j=0;j<40640;j++)t();
let M=canonical?0:.05,b=.6,g=.6,E=22+t()*25;const initial={time:M,level:b,target:g,thunder_timer:E,rng_calls:calls};const a=Array.from({length:4},()=>new Vec()),l=Array.from({length:4},()=>new Vec()),h=Array.from({length:8},()=>new Vec(0,0,-1,-1)),f={uTime:{value:0},uRain:{value:.6}},p={uPix:{value:.002},uDrip:{value:0}},m={visible:true},y={visible:true},_=new Vec();
const thunder=[],n={camera:{fov:74},render:{resolution:{x:1280,y:720}},renderer:{getDrawingBufferSize(out){out.copy({x:640,y:360})}},level:{},events:{emit:(name,event)=>thunder.push(event.intensity)}};
const update=eval('({'+text.slice(begin,end)+'}).update'),frames=[];
for(let frame=0;frame<(runtime?1450:canonical?3000:1000);frame++){
 if(frame===30)g=1;if(frame===400)g=0;if(frame===800)g=.3;
 const interiors=frame>=600&&frame<700?[]:level.interiorBoxes;const openings=frame>=700&&frame<750?[]:level.skylights;
 n.level.interiorBoxes=interiors.map(box=>({min:new Vec(...box.min),max:new Vec(...box.max)}));n.level.skylights=openings;
 n.camera.fov=60+frame%36;n.render.resolution={x:frame%7===0?0:1280,y:720};
 const height=n.render.resolution.x>8?720:360,dt=runtime?.05:[1/60,.05,.1][frame%3];update(dt);
 frames.push({fov:n.camera.fov,height,interiors,openings,target:g,time:M,level:b,timer:E,pixel:p.uPix.value,drip:p.uDrip.value,min:a.map(v=>[v.x,v.y,v.z]),max:l.map(v=>[v.x,v.y,v.z]),sky:h.map(v=>[v.x,v.y,v.z,v.w]),visible:m.visible,thunder:[...thunder],rng_state:(seed+Math.imul(calls,1831565813))>>>0,rng_calls:calls});
}
if(frames.some(row=>![row.time,row.level,row.timer,...row.thunder].every(Number.isFinite)))throw Error('nonfinite rain reference');
fs.writeFileSync('saltline-godot/assets/export/fixtures/'+(runtime?'rain-runtime-reference.json':canonical?'rain-canonical-reference.json':'rain-reference.json'),JSON.stringify({runtime,canonical,seed,initial,source_sha256:crypto.createHash('sha256').update(text).digest('hex'),update_sha256:crypto.createHash('sha256').update(text.slice(begin,end)).digest('hex'),frames}));console.log({frames:frames.length,thunder:thunder.length});
