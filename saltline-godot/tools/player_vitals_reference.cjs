const fs=require('fs'),text=fs.readFileSync('artifact-rendering-study/source/extracted/bundle-1.js','utf8'),data=JSON.parse(fs.readFileSync('saltline-godot/assets/prepared/scene.json'));
class Vec{constructor(x=0,y=0,z=0){this.set(x,y,z)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}copy(v){return this.set(v.x,v.y,v.z)}distanceTo(v){return Math.hypot(this.x-v.x,this.y-v.y,this.z-v.z)}applyEuler(){return this}toJSON(){return [this.x,this.y,this.z]}}
const K=Vec,_0=class{constructor(){this.set(0,0,0)}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}},Nt=data.modules.player.tuning,zi={eye:1.68,crouchEye:1.05,fov:74,radius:.32},Kn={seaY:-1.6};
const Hn=(v,a,b)=>Math.max(a,Math.min(b,v)),Is=v=>Hn(v,0,1),j0=(a,b,r,t)=>a+(b-a)*(1-Math.exp(-r*t)),ou=(a,b,v)=>{let t=Is((v-a)/(b-a));return t*t*(3-2*t)},u0=(a,b,t)=>a+(b-a)*t;
let hits=0,deaths=0;const camera={position:new Vec(),rotation:new _0(),fov:74,updateProjectionMatrix:()=>{}},post={};
const n={camera,render:{post},input:{},weapon:{ads:0},events:{on:()=>{},emit:(kind)=>{if(kind==='player:hit')hits++;if(kind==='player:dead')deaths++}},physics:{moveCapsule:(p,v,dt)=>{p.x+=v.x*dt;p.z+=v.z*dt;p.y+=v.y*dt;if(p.y<=0){p.y=0;v.y=Math.max(0,v.y);return {onGround:true}}return {onGround:false}}}};
let begin=text.indexOf('function xE(n) {'),end=text.indexOf('function ey(n)',begin),source=text.slice(begin,end).trim();
source=source.replace('return A;','A._state=()=>({health:A.health,alive:A.alive,hurtPulse:A.hurtPulse,lowHealth:S,sinceHit:T,shake:M,hits,deaths,position:A.pos.toJSON(),eye:A.eye.toJSON(),camera:[e.rotation.x,e.rotation.y,e.rotation.z],fov:e.fov,ads:A.ads,clock:_,enabled:A.enabled});A._vitals=(J)=>{T+=J;if(T>Nt.regenDelay&&A.health<A.maxHealth)A.health=Math.min(A.maxHealth,A.health+Nt.regenRate*J);W(J)};return A;');
const player=eval('('+source+')')(n),frames=[];
for(let frame=0;frame<600;frame++){
 if(frame===0)player.damage(20,new Vec(1,0,0));if(frame===60){player.invulnerable=true;player.damage(40)}if(frame===90){player.invulnerable=false;player.damage(10)}if(frame===150)player.heal(5);if(frame===360)player.damage(200);
 if(player.alive)player._vitals(1/60);else {n.weapon.ads=Math.exp(-(frame-360)*.1);player.update(1/60);}
 frames.push(player._state());
}
player.enabled=false;player.reset({pos:new Vec(3,.4,-2),yaw:.7});const reset=player._state();
fs.writeFileSync('saltline-godot/assets/export/fixtures/player-vitals-reference.json',JSON.stringify({frames,reset,scope:'Actual original damage/heal/W and dead N/Z/Q; controlled flat collision; living frames isolate regen and post pulses'}));console.log({frames:frames.length,hits,deaths,last:frames.at(-1)});
