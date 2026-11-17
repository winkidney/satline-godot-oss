const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8');
const callbackAt=text.indexOf('(G) => {',text.indexOf('n.events.on("thunder", (G) => {'));let brace=text.indexOf('{',callbackAt),depth=1,end=brace+1;while(depth){if(text[end]==='{')depth++;if(text[end]==='}')depth--;end++}
const begin=text.indexOf('(w.value =',text.indexOf('        frame(G) {'));const expression=text.slice(begin,text.indexOf(',\n            (u.material.uniforms.uFlash.value',begin));
class Vec{constructor(x,y,z){Object.assign(this,{x,y,z})}set(x,y,z){Object.assign(this,{x,y,z});return this}normalize(){const l=Math.hypot(this.x,this.y,this.z);this.x/=l;this.y/=l;this.z/=l;return this}toJSON(){return [this.x,this.y,this.z]}}
let draws=[];const Math=Object.create(globalThis.Math);Math.random=()=>draws.shift();
const w={t:99,power:0,value:0},u={material:{uniforms:{uFlashDir:{value:new Vec(-.5,.5,-.7).normalize()}}}};
const trigger=eval('('+text.slice(callbackAt,end)+')');const frames=[];
for(let frame=0;frame<500;frame++){
 let event=null;if([10,100,105,200,300,400].includes(frame)){event={intensity:[1,.7,0,-.2,2,.4][[10,100,105,200,300,400].indexOf(frame)],draws:[.1+(frame%7)*.1,.3,.7]};draws=[...event.draws];trigger(event)}
 const dt=[1/60,.05,.001,.1][frame%4];w.t+=dt;eval(expression);
 frames.push({event,time:w.t,power:w.power,value:w.value,direction:u.material.uniforms.uFlashDir.value.toJSON()});
}
fs.writeFileSync('saltline-godot/assets/export/fixtures/sky-weather-reference.json',JSON.stringify({frames}));console.log({frames:frames.length});
